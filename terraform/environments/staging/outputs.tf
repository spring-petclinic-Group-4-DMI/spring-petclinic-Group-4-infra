# ──────────────────────────────────────────────────────────────
# Staging Environment Outputs
# Project:  Spring PetClinic Microservices
# ──────────────────────────────────────────────────────────────

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = module.iam.github_oidc_provider_arn
}

output "github_actions_ci_role_arn" {
  description = "ARN of the GitHub Actions CI role"
  value       = module.iam.github_actions_ci_role_arn
}

output "terraform_role_arn" {
  description = "ARN of the Terraform role"
  value       = module.iam.terraform_role_arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node role"
  value       = module.iam.eks_node_role_arn
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster role"
  value       = module.iam.eks_cluster_role_arn
}

output "app_secret_arn" {
  description = "ARN of the staging application secret"
  value       = module.app_secrets.secret_arn
}

output "app_secret_name" {
  description = "Name of the staging application secret"
  value       = module.app_secrets.secret_name
}