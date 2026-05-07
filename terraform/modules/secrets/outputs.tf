output "secret_arn" {
  description = "ARN of the created AWS Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_id" {
  description = "ID of the created AWS Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.id
}

output "secret_name" {
  description = "Name of the created AWS Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.name
}
