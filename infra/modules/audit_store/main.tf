# DynamoDB tables for the control API: the audit log (who, what, when,
# before/after; STANDARDS §2) and idempotency keys (STANDARDS §5).

resource "aws_dynamodb_table" "audit" {
  name         = "${var.name_prefix}-audit-log"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"
  # checkov:skip=CKV_AWS_119: a customer-managed KMS key costs money; AWS-owned key encryption is on (ADR 0004).

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = var.deletion_protection

  tags = { Name = "${var.name_prefix}-audit-log" }
}

resource "aws_dynamodb_table" "idempotency" {
  name         = "${var.name_prefix}-idempotency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key"
  # checkov:skip=CKV_AWS_119: see the audit table.

  attribute {
    name = "key"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = var.deletion_protection

  tags = { Name = "${var.name_prefix}-idempotency" }
}
