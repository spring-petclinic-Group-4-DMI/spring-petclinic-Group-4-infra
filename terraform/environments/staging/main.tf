# ──────────────────────────────────────────────────────────────
# Staging Environment - Main
# Project:  Spring PetClinic Microservices
# Region:   us-east-1
# Owner:    Group 4 DevOps Team
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "spc-staging-ue1-tfstate"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "spc-staging-ue1-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = "Spring PetClinic"
    Environment = "Staging"
    ManagedBy   = "Terraform"
    Owner       = "Group-4-DevOps"
    CostCenter  = "Engineering-Internship"
  }

  app_secret_values = merge(
    {
      MYSQL_USERNAME = var.mysql_username
      MYSQL_PASSWORD = var.mysql_password
      OPENAI_API_KEY = var.openai_api_key
      DB_NAME        = var.db_name
    },
    var.additional_secret_values
  )
}

module "iam" {
  source = "../../modules/iam"

  environment    = var.environment
  aws_account_id = var.aws_account_id
  github_org     = var.github_org
  common_tags    = local.common_tags
}

module "ecr" {
  source            = "../../modules/ecr"
  aws_region        = var.aws_region
  environment       = var.environment
  repository_prefix = var.repository_prefix
}

module "app_secrets" {
  source                = "../../modules/secrets"
  project_code          = var.project_code
  environment_code      = var.environment_code
  region_code           = var.region_code
  component             = var.secret_component
  resource_name         = var.secret_resource_name
  resource_count        = var.secret_resource_count
  description           = var.secret_description
  kms_key_id            = var.kms_key_id
  create_secret_version = var.create_secret_version
  secret_values         = local.app_secret_values
  tags                  = local.common_tags
}
