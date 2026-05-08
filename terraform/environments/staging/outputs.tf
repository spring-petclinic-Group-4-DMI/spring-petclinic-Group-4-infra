
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
