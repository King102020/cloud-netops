output "subnet_ids" {
  description = "Subnet IDs keyed like var.subnets."
  value       = { for k, s in aws_subnet.this : k => s.id }
}

output "subnet_ids_by_tier" {
  description = "Subnet IDs grouped by tier."
  value = {
    for tier in distinct([for s in var.subnets : s.tier]) :
    tier => [for k, s in var.subnets : aws_subnet.this[k].id if s.tier == tier]
  }
}

output "route_table_ids" {
  description = "Route table ID per tier."
  value       = { for k, rt in aws_route_table.this : k => rt.id }
}

output "nat_gateway_id" {
  description = "NAT gateway ID, or null."
  value       = try(aws_nat_gateway.this[0].id, null)
}
