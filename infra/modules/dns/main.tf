# Route 53 private hosted zone = hq-srv-01's DNS role (§9.1), shared by all
# VPCs.

resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = "cnops private zone (replaces hq-srv-01 DNS)"
  # checkov:skip=CKV2_AWS_38: DNSSEC signing is for public zones; this zone is private.
  # checkov:skip=CKV2_AWS_39: Query logging needs a CloudWatch log group per zone; not worth the cost in the lab (ADR 0004).

  dynamic "vpc" {
    for_each = var.vpc_ids
    content {
      vpc_id = vpc.value
    }
  }

  tags = { Name = var.zone_name }
}

resource "aws_route53_record" "a" {
  for_each = var.a_records

  zone_id = aws_route53_zone.this.zone_id
  # checkov:skip=CKV2_AWS_23: records point at reserved server addresses from the IP plan; no instance yet.
  name    = "${each.key}.${var.zone_name}"
  type    = "A"
  ttl     = 300
  records = [each.value]
}
