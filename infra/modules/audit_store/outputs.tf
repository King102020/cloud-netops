output "audit_table_name" {
  description = "Audit log table name."
  value       = aws_dynamodb_table.audit.name
}

output "idempotency_table_name" {
  description = "Idempotency key table name."
  value       = aws_dynamodb_table.idempotency.name
}
