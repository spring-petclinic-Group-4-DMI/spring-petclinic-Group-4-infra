output "rds_endpoint" {
  description = "RDS connection endpoint — used by microservices to connect to MySQL"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_port" {
  description = "RDS port number"
  value       = aws_db_instance.mysql.port
}

output "rds_db_name" {
  description = "Name of the MySQL database created"
  value       = aws_db_instance.mysql.db_name
}

output "rds_security_group_id" {
  description = "Security group ID attached to RDS — referenced by other modules if needed"
  value       = aws_security_group.rds_sg.id
}
