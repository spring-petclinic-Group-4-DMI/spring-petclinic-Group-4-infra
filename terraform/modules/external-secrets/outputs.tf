output "role_arn" {
  description = "IRSA role ARN assumed by the ESO controller (informational)"
  value       = aws_iam_role.this.arn
}

output "namespace" {
  description = "Namespace where the ESO controller runs"
  value       = "external-secrets"
}

output "service_account_name" {
  description = "Service account the ClusterSecretStore must reference for JWT auth"
  value       = "external-secrets"
}
