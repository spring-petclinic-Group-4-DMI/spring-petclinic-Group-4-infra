locals {
  name_prefix = "${var.project}-${var.environment}"
  db_name     = "petclinic"
  username    = "petclinic"
}

resource "random_password" "master" {
  length           = 20
  special          = true
  min_special      = 2
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-rds-subnets"
  description = "RDS subnet group for ${local.name_prefix}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-subnets"
  })
}

resource "aws_db_parameter_group" "this" {
  name        = "${local.name_prefix}-mysql8"
  family      = "mysql8.0"
  description = "Parameter group for ${local.name_prefix} MySQL"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = local.db_name
  username = local.username
  password = random_password.master.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection
  apply_immediately       = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-mysql"
  })
}

# --- RDS credentials in Secrets Manager ---

resource "aws_secretsmanager_secret" "rds" {
  name        = "petclinic/${var.environment}/rds-credentials"
  description = "RDS master credentials for ${local.name_prefix}"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = local.username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = local.db_name
  })
}
