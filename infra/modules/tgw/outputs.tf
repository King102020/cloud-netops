output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.this.id
}

output "route_table_id" {
  description = "The TGW route table every attachment uses."
  value       = aws_ec2_transit_gateway_route_table.this.id
}

output "attachment_ids" {
  description = "VPC attachment ID per site."
  value       = { for k, a in aws_ec2_transit_gateway_vpc_attachment.this : k => a.id }
}

output "vpc_routes" {
  description = "VPC routes pointing at the TGW: key => { route_table_id, destination }."
  value       = local.vpc_routes
}
