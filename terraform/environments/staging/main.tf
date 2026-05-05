# ──────────────────────────────────────────────────────────────
# Staging Environment - Main
# Project:  Spring PetClinic Microservices
# Region:   us-east-1
# Owner:    Group 4 DevOps Team
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.0"

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
}

# ──────────────────────────────────────────────────────────────
# IAM Module
# ──────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  environment    = var.environment
  aws_account_id = var.aws_account_id
  github_org     = var.github_org
  common_tags    = local.common_tags
}