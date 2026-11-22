# Cloud NetOps — local environment (LocalStack).
# Every CIDR below comes from docs/network-design.md §9.2.

locals {
  env    = "local"
  prefix = "cnops-${local.env}"

  tags = {
    Project     = "cloud-netops"
    Environment = local.env
    Owner       = var.owner
    ManagedBy   = "terraform"
  }

  az = {
    a = "${var.region}a"
    b = "${var.region}b"
  }

  # ---- Sites (= VPCs). Second octet = on-prem + 100. ----
  sites = {
    hq  = { cidr = "10.110.0.0/16", internet = true }
    br1 = { cidr = "10.120.0.0/16", internet = false }
    br2 = { cidr = "10.130.0.0/16", internet = false }
  }

  # ---- Subnets (= VLANs). Third octet = VLAN in AZ a, VLAN + 1 in AZ b. ----
  base_subnets = {
    hq = {
      "public-a"  = { cidr_block = "10.110.0.0/24", availability_zone = local.az.a, tier = "public" }
      "public-b"  = { cidr_block = "10.110.1.0/24", availability_zone = local.az.b, tier = "public" }
      "users-a"   = { cidr_block = "10.110.10.0/24", availability_zone = local.az.a, tier = "users" }
      "users-b"   = { cidr_block = "10.110.11.0/24", availability_zone = local.az.b, tier = "users" }
      "servers-a" = { cidr_block = "10.110.20.0/24", availability_zone = local.az.a, tier = "servers" }
      "servers-b" = { cidr_block = "10.110.21.0/24", availability_zone = local.az.b, tier = "servers" }
      "mgmt-a"    = { cidr_block = "10.110.99.0/27", availability_zone = local.az.a, tier = "mgmt" }
      "mgmt-b"    = { cidr_block = "10.110.99.32/27", availability_zone = local.az.b, tier = "mgmt" }
      "tgw-a"     = { cidr_block = "10.110.250.0/28", availability_zone = local.az.a, tier = "tgw" }
      "tgw-b"     = { cidr_block = "10.110.250.16/28", availability_zone = local.az.b, tier = "tgw" }
    }
    br1 = {
      "users-a" = { cidr_block = "10.120.10.0/24", availability_zone = local.az.a, tier = "users" }
      "users-b" = { cidr_block = "10.120.11.0/24", availability_zone = local.az.b, tier = "users" }
      "mgmt-a"  = { cidr_block = "10.120.99.0/27", availability_zone = local.az.a, tier = "mgmt" }
      "mgmt-b"  = { cidr_block = "10.120.99.32/27", availability_zone = local.az.b, tier = "mgmt" }
      "tgw-a"   = { cidr_block = "10.120.250.0/28", availability_zone = local.az.a, tier = "tgw" }
      "tgw-b"   = { cidr_block = "10.120.250.16/28", availability_zone = local.az.b, tier = "tgw" }
    }
    br2 = {
      "users-a" = { cidr_block = "10.130.10.0/24", availability_zone = local.az.a, tier = "users" }
      "users-b" = { cidr_block = "10.130.11.0/24", availability_zone = local.az.b, tier = "users" }
      "mgmt-a"  = { cidr_block = "10.130.99.0/27", availability_zone = local.az.a, tier = "mgmt" }
      "mgmt-b"  = { cidr_block = "10.130.99.32/27", availability_zone = local.az.b, tier = "mgmt" }
      "tgw-a"   = { cidr_block = "10.130.250.0/28", availability_zone = local.az.a, tier = "tgw" }
      "tgw-b"   = { cidr_block = "10.130.250.16/28", availability_zone = local.az.b, tier = "tgw" }
    }
  }

  # ---- Runtime inputs written by the control API (phase 4). ----
  managed_rules_file   = "${path.module}/${var.managed_dir}/firewall_rules.json"
  managed_subnets_file = "${path.module}/${var.managed_dir}/subnets.json"
  managed_rules        = fileexists(local.managed_rules_file) ? jsondecode(file(local.managed_rules_file)) : []
  managed_subnets      = fileexists(local.managed_subnets_file) ? jsondecode(file(local.managed_subnets_file)) : []

  subnets = {
    for site, base in local.base_subnets : site => merge(base, {
      for s in local.managed_subnets : s.name => {
        cidr_block        = s.cidr_block
        availability_zone = local.az[s.az]
        tier              = s.tier
      } if s.site == site
    })
  }

  firewall_rules = {
    for site in keys(local.sites) : site => [
      for r in local.managed_rules : {
        id          = r.id
        tier        = r.tier
        protocol    = r.protocol
        from_port   = r.from_port
        to_port     = r.to_port
        cidr        = r.cidr
        description = r.description
      } if r.site == site && try(r.enabled, true)
    ]
  }

  # USERS / MGMT networks on-prem and in the cloud (ACL TO-SERVERS, MGMT-VTY).
  users_cidrs = ["10.10.10.0/24", "10.20.10.0/24", "10.30.10.0/24", "10.110.10.0/23", "10.120.10.0/23", "10.130.10.0/23"]
  mgmt_cidrs  = ["10.10.99.0/27", "10.20.99.0/27", "10.30.99.0/27", "10.110.99.0/26", "10.120.99.0/26", "10.130.99.0/26"]
  onprem      = ["10.10.0.0/16", "10.20.0.0/16", "10.30.0.0/16"]
}

# ---------------- VPCs ----------------
module "vpc" {
  source   = "../../modules/vpc"
  for_each = local.sites

  name                    = "${local.prefix}-${each.key}-vpc"
  cidr_block              = each.value.cidr
  enable_internet_gateway = each.value.internet
  enable_flow_logs        = var.enable_flow_logs
}

module "subnets" {
  source   = "../../modules/subnets"
  for_each = local.sites

  vpc_id                      = module.vpc[each.key].vpc_id
  name_prefix                 = "${local.prefix}-${each.key}"
  subnets                     = local.subnets[each.key]
  internet_gateway_id         = module.vpc[each.key].internet_gateway_id
  create_public_default_route = each.value.internet

  # hq only: one NAT gateway = hq-edge-01 PAT for the whole company.
  nat_gateway_subnet_key = each.value.internet ? "public-a" : null
  nat_route_tiers        = each.value.internet ? ["users", "servers", "mgmt", "tgw"] : []
}

# ---------------- Transit Gateway (= hq-core-01) ----------------
module "tgw" {
  source = "../../modules/tgw"

  name_prefix = local.prefix
  # Every tier except the TGW subnets themselves points at the TGW. Tiers come
  # from local.subnets (known at plan time), so subnets the API adds later are
  # routed too.
  #   hq:       10.0.0.0/8 -> TGW (internet stays on the local NAT gateway)
  #   branches: 0.0.0.0/0  -> TGW (like the OSPF default towards HQ)
  vpc_attachments = {
    for site, cfg in local.sites : site => {
      vpc_id     = module.vpc[site].vpc_id
      subnet_ids = module.subnets[site].subnet_ids_by_tier["tgw"]
      route_table_ids = {
        for t in distinct([for s in values(local.subnets[site]) : s.tier if s.tier != "tgw"]) :
        t => module.subnets[site].route_table_ids[t]
      }
      destinations = cfg.internet ? ["10.0.0.0/8"] : ["0.0.0.0/0"]
    }
  }
  default_route_attachment = "hq"
}

# ---------------- Security (= ACLs) ----------------
module "security" {
  source   = "../../modules/security"
  for_each = local.sites

  vpc_id      = module.vpc[each.key].vpc_id
  name_prefix = "${local.prefix}-${each.key}"
  tiers       = toset([for s in values(local.subnets[each.key]) : s.tier if contains(["users", "servers", "mgmt"], s.tier)])
  users_cidrs = local.users_cidrs
  mgmt_cidrs  = local.mgmt_cidrs
  subnet_ids_by_nacl = {
    private = flatten([
      for t, ids in module.subnets[each.key].subnet_ids_by_tier : ids if t != "public"
    ])
    public = lookup(module.subnets[each.key].subnet_ids_by_tier, "public", [])
  }
  firewall_rules = local.firewall_rules[each.key]
}

# ---------------- Hybrid link to on-prem hq-edge-01 ----------------
module "vpn" {
  source = "../../modules/vpn"
  count  = var.enable_vpn ? 1 : 0

  name_prefix                    = local.prefix
  transit_gateway_id             = module.tgw.transit_gateway_id
  transit_gateway_route_table_id = module.tgw.route_table_id
  customer_gateway_ip            = "203.0.113.2"
  onprem_cidrs                   = local.onprem
}

# ---------------- DNS (= hq-srv-01) ----------------
module "dns" {
  source = "../../modules/dns"

  vpc_ids = { for k, v in module.vpc : k => v.vpc_id }
  a_records = {
    "intranet" = "10.110.20.10"
  }
}

# ---------------- Control API state ----------------
module "audit_store" {
  source = "../../modules/audit_store"

  name_prefix = local.prefix
}
