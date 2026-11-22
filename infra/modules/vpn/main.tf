# Site-to-site VPN from on-prem hq-edge-01 (customer gateway) to the TGW.
# docs/network-design.md §9.1. Static routing keeps the route table explicit;
# the on-prem /16s point at the VPN attachment.

resource "aws_customer_gateway" "this" {
  bgp_asn    = var.customer_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = { Name = "${var.name_prefix}-cgw-hq-edge-01" }
}

resource "aws_vpn_connection" "this" {
  customer_gateway_id = aws_customer_gateway.this.id
  transit_gateway_id  = var.transit_gateway_id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_inside_cidr = var.tunnel_inside_cidrs[0]
  tunnel2_inside_cidr = var.tunnel_inside_cidrs[1]

  # Strong crypto only (Well-Architected security pillar).
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase1_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase1_dh_group_numbers      = [20]
  tunnel2_phase1_dh_group_numbers      = [20]
  tunnel1_phase2_dh_group_numbers      = [20]
  tunnel2_phase2_dh_group_numbers      = [20]

  tags = { Name = "${var.name_prefix}-vpn-hq" }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn" {
  transit_gateway_attachment_id  = aws_vpn_connection.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route" "onprem" {
  for_each = toset(var.onprem_cidrs)

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = aws_vpn_connection.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}
