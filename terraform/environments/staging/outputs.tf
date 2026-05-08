
# ── RDS Module outputs — SPC-39 ──────────────────────────────────────────────

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
  description = "ARN of the validated ACM wildcard certificate (*.petclinic-group4.com + apex). Attach this to the ALB HTTPS listener (port 443) in your Helm ingress values or the aws_lb_listener resource in SPC-005-T8."
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "staging_url" {
  description = "The staging HTTPS URL for the Spring PetClinic application."
  value       = "https://staging.${var.domain_name}"
}

