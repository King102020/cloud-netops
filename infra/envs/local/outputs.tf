output "vpcs" {
  description = "Per site: VPC ID and CIDR."
  value = {
    for k, v in module.vpc : k => { id = v.vpc_id, cidr = v.cidr_block }
  }
}

output "subnets" {
  description = "Per site: subnet IDs keyed by <tier>-<az>."
  value       = { for k, s in module.subnets : k => s.subnet_ids }
}

output "transit_gateway" {
  description = "TGW, its route table and attachments."
  value = {
    id             = module.tgw.transit_gateway_id
    route_table_id = module.tgw.route_table_id
    attachments    = module.tgw.attachment_ids
  }
}

output "security_groups" {
  description = "Per site: security group ID per tier."
  value       = { for k, s in module.security : k => s.security_group_ids }
}

output "firewall_rule_ids" {
  description = "Per site: ingress rule IDs (baseline and API-managed)."
  value       = { for k, s in module.security : k => s.ingress_rule_ids }
}

output "vpn_connection_id" {
  description = "Site-to-site VPN to hq-edge-01, or null."
  value       = try(module.vpn[0].vpn_connection_id, null)
}

output "dns_zone" {
  description = "Private hosted zone."
  value       = { id = module.dns.zone_id, name = module.dns.zone_name }
}

output "dynamodb_tables" {
  description = "Tables the control API uses."
  value = {
    audit       = module.audit_store.audit_table_name
    idempotency = module.audit_store.idempotency_table_name
  }
}
