output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider (created or referenced)"
  value       = local.oidc_provider_arn
}

output "role_arns" {
  description = "Map of role name → role ARN. Paste these into GitHub Secrets as AWS_ROLE_ARN."
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}

output "role_names" {
  description = "Map of role name → role name (for reference)"
  value       = { for k, r in aws_iam_role.this : k => r.name }
}
