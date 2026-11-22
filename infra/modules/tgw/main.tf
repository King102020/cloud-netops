# Transit Gateway = hq-core-01, the WAN hub (docs/network-design.md §9.1).
# One explicit route table (no "default" association/propagation), so every
# route is visible in code, like the OSPF design.

locals {
  # One aws_route per (attachment, VPC route table, destination).
  vpc_routes = merge([
    for att_key, att in var.vpc_attachments : merge([
      for rt_key, rt_id in att.route_table_ids : {
        for dest in att.destinations :
        "${att_key}/${rt_key}/${dest}" => { route_table_id = rt_id, destination = dest }
      }
    ]...)
  ]...)
}

resource "aws_ec2_transit_gateway" "this" {
  description                     = "cnops WAN hub (hq-core-01)"
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = { Name = "${var.name_prefix}-tgw" }
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${var.name_prefix}-tgw-rt" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  transit_gateway_id                              = aws_ec2_transit_gateway.this.id
  vpc_id                                          = each.value.vpc_id
  subnet_ids                                      = each.value.subnet_ids
  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = { Name = "${var.name_prefix}-${each.key}-tgw-attach" }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc" {
  for_each = var.vpc_attachments

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

# Propagation = the OSPF ABR summary: each VPC advertises its one /16.
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc" {
  for_each = var.vpc_attachments

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

# Default route to the internet via the hq VPC (= OSPF default from hq-edge-01).
resource "aws_ec2_transit_gateway_route" "default" {
  count = var.default_route_attachment != null ? 1 : 0

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[var.default_route_attachment].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

# VPC side: send the listed destinations to the TGW.
resource "aws_route" "to_tgw" {
  for_each = local.vpc_routes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
