# Offline tests: `terraform test` with a mocked AWS provider. No LocalStack,
# no network. They check that the code matches docs/network-design.md §9.

mock_provider "aws" {
  # Mocked IDs must look real enough for resources that validate them.
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_ec2_transit_gateway" {
    defaults = { id = "tgw-0123456789abcdef0" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:ap-south-1:000000000000:log-group:mock" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::000000000000:role/mock" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  managed_dir = "tests/fixtures/none" # no managed rules unless a run says so
}

run "vpcs_match_ip_plan" {
  command = apply

  assert {
    condition     = module.vpc["hq"].cidr_block == "10.110.0.0/16"
    error_message = "hq VPC must be 10.110.0.0/16 (on-prem + 100)."
  }
  assert {
    condition     = module.vpc["br1"].cidr_block == "10.120.0.0/16" && module.vpc["br2"].cidr_block == "10.130.0.0/16"
    error_message = "Branch VPCs must be 10.120/16 and 10.130/16."
  }
  assert {
    condition     = length(module.vpc) == 3
    error_message = "Exactly three sites."
  }
}

run "only_hq_has_internet" {
  command = apply

  assert {
    condition     = module.vpc["hq"].internet_gateway_id != null
    error_message = "hq needs the internet gateway."
  }
  assert {
    condition     = module.vpc["br1"].internet_gateway_id == null && module.vpc["br2"].internet_gateway_id == null
    error_message = "Branches must exit via hq, like on-prem."
  }
  assert {
    condition     = module.subnets["hq"].nat_gateway_id != null && module.subnets["br1"].nat_gateway_id == null
    error_message = "One NAT gateway, in hq."
  }
}

run "subnets_two_azs_per_tier" {
  command = apply

  assert {
    condition = alltrue([
      for site, s in module.subnets : alltrue([for tier, ids in s.subnet_ids_by_tier : length(ids) == 2])
    ])
    error_message = "Every tier needs one subnet in each of the two AZs."
  }
  assert {
    condition     = length(module.subnets["hq"].subnet_ids) == 10 && length(module.subnets["br1"].subnet_ids) == 6
    error_message = "hq has 10 subnets, branches 6 (design §9.2)."
  }
}

run "tgw_routes" {
  command = apply

  assert {
    condition     = length(module.tgw.attachment_ids) == 3
    error_message = "One TGW attachment per site."
  }
  assert {
    condition     = length([for k, r in module.tgw.vpc_routes : r if r.destination == "0.0.0.0/0"]) == 4
    error_message = "Branches send everything to the TGW (users + mgmt in br1 and br2)."
  }
  assert {
    condition     = length([for k, r in module.tgw.vpc_routes : r if r.destination == "10.0.0.0/8"]) == 4
    error_message = "hq sends internal traffic to the TGW from public, users, servers and mgmt."
  }
}

run "baseline_rules_never_open_to_world" {
  command = apply

  assert {
    condition = alltrue(flatten([
      for site, sec in module.security : [for k, r in sec.ingress_rules : r.cidr != "0.0.0.0/0"]
    ]))
    error_message = "No ingress rule may allow 0.0.0.0/0 (default deny)."
  }
  assert {
    condition     = contains(keys(module.security["hq"].ingress_rules), "servers-ssh-10.10.99.0/27")
    error_message = "MGMT SSH to servers (ACL TO-SERVERS line 90) is missing."
  }
}

run "managed_inputs_are_applied" {
  command = apply

  variables {
    managed_dir = "tests/fixtures/managed"
  }

  assert {
    condition     = contains(keys(module.security["hq"].ingress_rules), "managed-fw-0001")
    error_message = "Enabled API-managed rule fw-0001 must become an SG rule."
  }
  assert {
    condition     = !contains(keys(module.security["hq"].ingress_rules), "managed-fw-0002")
    error_message = "Disabled rule fw-0002 must not be applied."
  }
  assert {
    condition     = contains(keys(module.subnets["br1"].subnet_ids), "servers-a")
    error_message = "API-managed subnet br1 servers-a must be created."
  }
  assert {
    condition     = contains(keys(module.security["br1"].security_group_ids), "servers")
    error_message = "A new tier gets its own security group."
  }
}

run "rejects_world_open_rule" {
  command = plan

  module {
    source = "../../modules/security"
  }

  variables {
    vpc_id      = "vpc-0123456789abcdef0"
    name_prefix = "cnops-local-hq"
    tiers       = ["servers"]
    users_cidrs = []
    mgmt_cidrs  = []
    firewall_rules = [{
      id   = "bad", tier = "servers", protocol = "tcp", from_port = 22, to_port = 22,
      cidr = "0.0.0.0/0", description = "open SSH to the world"
    }]
  }

  expect_failures = [var.firewall_rules]
}

run "rejects_non_local_endpoint" {
  command = plan

  variables {
    localstack_endpoint = "https://ec2.ap-south-1.amazonaws.com"
  }

  expect_failures = [var.localstack_endpoint]
}
