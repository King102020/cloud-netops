# Security groups (= ACLs TO-SERVERS / MGMT-VTY) and network ACLs (subnet
# level, stateless). docs/network-design.md §6 and §9.1.
# SGs are stateful, so the ACL lines for "replies" are not needed here.

locals {
  internal = "10.0.0.0/8"

  # Baseline ingress, mirroring the on-prem ACLs line by line.
  baseline = merge(
    contains(var.tiers, "servers") ? merge(
      {
        "servers-dns-udp"   = { tier = "servers", protocol = "udp", from = 53, to = 53, cidr = local.internal, why = "10 internal DNS" }
        "servers-dns-tcp"   = { tier = "servers", protocol = "tcp", from = 53, to = 53, cidr = local.internal, why = "20 DNS over TCP" }
        "servers-icmp-echo" = { tier = "servers", protocol = "icmp", from = 8, to = 0, cidr = local.internal, why = "60 ping, internal only" }
      },
      { for c in var.users_cidrs : "servers-http-${c}" => { tier = "servers", protocol = "tcp", from = 80, to = 80, cidr = c, why = "30 intranet web" } },
      { for c in var.users_cidrs : "servers-https-${c}" => { tier = "servers", protocol = "tcp", from = 443, to = 443, cidr = c, why = "40 intranet web TLS" } },
      { for c in var.users_cidrs : "servers-smb-${c}" => { tier = "servers", protocol = "tcp", from = 445, to = 445, cidr = c, why = "50 file shares" } },
      { for c in var.mgmt_cidrs : "servers-ssh-${c}" => { tier = "servers", protocol = "tcp", from = 22, to = 22, cidr = c, why = "90 admin SSH from MGMT" } },
    ) : {},
    contains(var.tiers, "users") ? {
      "users-icmp-echo" = { tier = "users", protocol = "icmp", from = 8, to = 0, cidr = local.internal, why = "ping, internal only" }
    } : {},
    contains(var.tiers, "mgmt") ? merge(
      { for c in var.mgmt_cidrs : "mgmt-ssh-${c}" => { tier = "mgmt", protocol = "tcp", from = 22, to = 22, cidr = c, why = "MGMT-VTY: SSH from MGMT only" } },
      { "mgmt-icmp-echo" = { tier = "mgmt", protocol = "icmp", from = 8, to = 0, cidr = local.internal, why = "ping, internal only" } },
    ) : {},
  )

  # Rules added at runtime by the control API (phase 4), one map entry per rule.
  managed = {
    for r in var.firewall_rules : "managed-${r.id}" => {
      tier = r.tier, protocol = r.protocol, from = r.from_port, to = r.to_port, cidr = r.cidr,
      why  = "managed ${r.id}: ${r.description}"
    } if contains(var.tiers, r.tier)
  }

  ingress = merge(local.baseline, local.managed)

  # Egress: internal anything; internet only for web + DNS (least privilege).
  egress = merge(
    { for t in var.tiers : "${t}-internal" => { tier = t, protocol = "-1", from = null, to = null, cidr = local.internal, why = "internal traffic" } },
    { for t in setsubtract(var.tiers, ["mgmt"]) : "${t}-https" => { tier = t, protocol = "tcp", from = 443, to = 443, cidr = "0.0.0.0/0", why = "internet HTTPS via NAT" } },
    { for t in setsubtract(var.tiers, ["mgmt"]) : "${t}-http" => { tier = t, protocol = "tcp", from = 80, to = 80, cidr = "0.0.0.0/0", why = "internet HTTP via NAT" } },
  )
}

resource "aws_security_group" "this" {
  for_each = var.tiers

  name        = "${var.name_prefix}-${each.key}-sg"
  description = "cnops ${each.key} tier (see docs/network-design.md section 6)"
  vpc_id      = var.vpc_id
  # checkov:skip=CKV2_AWS_5: network-only project; SGs are ready for workloads, none are deployed yet.

  tags = { Name = "${var.name_prefix}-${each.key}-sg", Tier = each.key }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress

  security_group_id = aws_security_group.this[each.value.tier].id
  ip_protocol       = each.value.protocol
  from_port         = each.value.from
  to_port           = each.value.to
  cidr_ipv4         = each.value.cidr
  description       = substr(each.value.why, 0, 255)

  tags = { Name = each.key }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress

  security_group_id = aws_security_group.this[each.value.tier].id
  ip_protocol       = each.value.protocol
  from_port         = each.value.from
  to_port           = each.value.to
  cidr_ipv4         = each.value.cidr
  description       = each.value.why

  tags = { Name = each.key }
}

# ---- Network ACLs (stateless, subnet level) ----
# Allow internal traffic and return traffic on the ephemeral port range;
# everything else hits the implicit deny. 32768-65535 (not 1024-65535) keeps
# well-known service ports such as 3389/RDP closed to the internet.
resource "aws_network_acl" "this" {
  for_each = { for k, ids in var.subnet_ids_by_nacl : k => ids if length(ids) > 0 }

  vpc_id     = var.vpc_id
  subnet_ids = each.value
  # checkov:skip=CKV2_AWS_1: attached via subnet_ids above; checkov cannot follow the module input.

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = local.internal
    from_port  = 0
    to_port    = 0
  }

  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = var.ephemeral_port_from
    to_port    = 65535
  }

  ingress {
    rule_no    = 210
    action     = "allow"
    protocol   = "udp"
    cidr_block = "0.0.0.0/0"
    from_port  = var.ephemeral_port_from
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "${var.name_prefix}-${each.key}-nacl" }
}
