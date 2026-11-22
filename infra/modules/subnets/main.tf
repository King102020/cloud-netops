# Subnets (= VLANs, one per AZ), one route table per tier, optional NAT
# gateway (= hq-edge-01 PAT). docs/network-design.md §9.

locals {
  tiers = toset([for s in var.subnets : s.tier])
}

resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-${each.key}"
    Tier = each.value.tier
  }
}

resource "aws_route_table" "this" {
  for_each = local.tiers

  vpc_id = var.vpc_id
  tags   = { Name = "${var.name_prefix}-${each.key}-rt", Tier = each.key }
}

resource "aws_route_table_association" "this" {
  for_each = var.subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.tier].id
}

# Public tier: default route to the internet gateway.
resource "aws_route" "public_default" {
  # A plan-time flag, not "gateway id != null": the id is unknown until apply.
  count = var.create_public_default_route ? 1 : 0

  route_table_id         = aws_route_table.this["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

# ---- NAT gateway ----
# One NAT gateway, not one per AZ: a deliberate cost trade-off (ADR 0004).
resource "aws_eip" "nat" {
  count = var.nat_gateway_subnet_key != null ? 1 : 0

  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_subnet_key != null ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.this[var.nat_gateway_subnet_key].id
  tags          = { Name = "${var.name_prefix}-nat" }
}

resource "aws_route" "nat_default" {
  for_each = var.nat_gateway_subnet_key != null ? toset(var.nat_route_tiers) : toset([])

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}
