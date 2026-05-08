locals {
  secret_full_name = join("-", [
    var.project_code,
    var.environment_code,
    var.region_code,
    var.component,
    var.resource_name,
    var.resource_count
  ])

  default_tags = {
    Project     = "Spring PetClinic"
    Environment = var.environment_code == "stg" ? "Staging" : "Production"
    ManagedBy   = "Terraform"
    Owner       = "Group-4-DevOps"
    CostCenter  = "Engineering-Internship"
  }
}

resource "aws_secretsmanager_secret" "this" {
  name                    = local.secret_full_name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id

  tags = merge(local.default_tags, var.tags)
}

resource "aws_secretsmanager_secret_version" "this" {
  count = var.create_secret_version ? 1 : 0

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.secret_values)
}
