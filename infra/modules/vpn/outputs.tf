output "vpn_connection_id" {
  description = "VPN connection ID."
  value       = aws_vpn_connection.this.id
}

output "customer_gateway_id" {
  description = "Customer gateway ID (hq-edge-01)."
  value       = aws_customer_gateway.this.id
}

output "transit_gateway_attachment_id" {
  description = "TGW attachment created for the VPN."
  value       = aws_vpn_connection.this.transit_gateway_attachment_id
}
