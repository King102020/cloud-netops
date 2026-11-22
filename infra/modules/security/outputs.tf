output "security_group_ids" {
  description = "Security group ID per tier."
  value       = { for k, sg in aws_security_group.this : k => sg.id }
}

output "ingress_rule_ids" {
  description = "Ingress rule IDs keyed by rule name (baseline and managed)."
  value       = { for k, r in aws_vpc_security_group_ingress_rule.this : k => r.security_group_rule_id }
}

output "network_acl_ids" {
  description = "NACL ID per group."
  value       = { for k, n in aws_network_acl.this : k => n.id }
}

output "ingress_rules" {
  description = "All ingress rules (baseline + managed) with tier, protocol, ports, cidr and reason."
  value       = local.ingress
}
