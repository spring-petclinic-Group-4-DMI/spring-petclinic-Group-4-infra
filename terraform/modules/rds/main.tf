# ──────────────────────────────────────────────────────────────
# RDS MySQL Module

# Security Group — controls who can reach RDS on port 3306
resource "aws_security_group" "rds_sg" {
  name        = "spc-${var.environment}-ue1-rds-sg"
  description = "Allow MySQL access from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-rds-sg"
  })
}

# Subnet Group — tells RDS which subnets it can use
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "spc-${var.environment}-ue1-rds-subnet-group"
  description = "Private subnets for RDS MySQL instance"
  subnet_ids  = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-rds-subnet-group"
  })
}

# Parameter Group — MySQL 8.0 configuration
resource "aws_db_parameter_group" "rds_params" {
  name        = "spc-${var.environment}-ue1-rds-params"
  family      = "mysql8.0"
  description = "Custom parameter group for PetClinic MySQL 8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-rds-params"
  })
}

# RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  identifier        = "spc-${var.environment}-ue1-rds-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  parameter_group_name   = aws_db_parameter_group.rds_params.name

  # Production hardening
  multi_az            = false # set to true in prod
  publicly_accessible = false # never expose RDS publicly
  deletion_protection = false # set to true in prod
  skip_final_snapshot = true  # set to false in prod

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Monitoring
  performance_insights_enabled = true

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-rds-db"
  })
}
