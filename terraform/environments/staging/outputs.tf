
output "rds_endpoint" {
  description = "RDS MySQL endpoint — used by microservices to connect to the database"
  value       = module.rds.rds_endpoint
}

output "rds_port" {
  description = "RDS MySQL port number"
  value       = module.rds.rds_port
}

output "rds_db_name" {
  description = "Name of the MySQL database created in RDS"
  value       = module.rds.rds_db_name
}

output "rds_security_group_id" {
  description = "Security group ID attached to RDS"
  value       = module.rds.rds_security_group_id
}
output "app_secret_arn" {
  description = "ARN of the staging application secret."
  value       = module.app_secrets.secret_arn
}

output "app_secret_name" {
  description = "Name of the staging application secret."
  value       = module.app_secrets.secret_name
}

output "certificate_arn" {
  description = "ARN of the ACM certificate — comes from ALB module"
  value       = module.alb.acm_certificate_arn
}

output "staging_url" {
  description = "The staging HTTPS URL for the Spring PetClinic application."
  value       = "https://staging.${var.domain_name}"
}
output "karpenter_controller_role_arn" {
  description = "Karpenter controller IAM role ARN — goes into Helm values"
  value       = module.karpenter.karpenter_controller_role_arn
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = module.karpenter.karpenter_node_instance_profile_name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for spot interruption handling"
  value       = module.karpenter.karpenter_interruption_queue_name
}

