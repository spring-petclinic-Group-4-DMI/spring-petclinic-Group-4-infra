output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "cluster_security_group_id" {
  description = "EKS-created cluster security group attached to managed node group ENIs"
  value       = module.eks.cluster_security_group_id
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service name"
  value       = module.ecr.repository_urls
}

output "rds_endpoint" {
  description = "RDS endpoint hostname"
  value       = module.rds.endpoint
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN for RDS master credentials"
  value       = module.rds.secret_arn
}

output "openai_secret_arn" {
  description = "Secrets Manager ARN for the OpenAI API key"
  value       = module.secrets.openai_secret_arn
}

output "karpenter_role_arn" {
  description = "Karpenter controller IRSA role ARN"
  value       = module.karpenter.karpenter_role_arn
}

output "karpenter_queue_name" {
  description = "Karpenter interruption queue name"
  value       = module.karpenter.karpenter_queue_name
}

output "karpenter_instance_profile_name" {
  description = "Instance profile for Karpenter-launched nodes"
  value       = module.karpenter.karpenter_instance_profile_name
}

output "aws_load_balancer_controller_role_arn" {
  description = "IRSA role ARN used by AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller.role_arn
}

output "route53_name_servers" {
  description = "Route 53 hosted zone NS records (null if domain_name not set)"
  value       = try(module.dns[0].name_servers, null)
}

output "acm_certificate_arn" {
  description = "Validated wildcard ACM certificate ARN (null if domain_name not set)"
  value       = try(module.dns[0].certificate_arn, null)
}

output "github_actions_app_role_arn" {
  description = "Role ARN for the spring-petclinic-microservices repo. Paste into AWS_ROLE_ARN in that repo's GitHub Secrets."
  value       = module.github_oidc.role_arns["petclinic-app-github-actions"]
}

output "github_actions_infra_role_arn" {
  description = "Role ARN for the petclinic-platform repo. Paste into AWS_ROLE_ARN in this repo's GitHub Secrets."
  value       = module.github_oidc.role_arns["petclinic-infra-github-actions"]
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN (informational)"
  value       = module.github_oidc.oidc_provider_arn
}
