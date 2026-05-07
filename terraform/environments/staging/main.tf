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

# ──────────────────────────────────────────────────────────────
# Secrets Module
# ──────────────────────────────────────────────────────────────
module "app_secrets" {
  source = "../../modules/secrets"

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

# ── VPC Module — written by Cloud/Infra Eng 1 (SPC-010) ─────────────────────
# This call block added temporarily to unblock ALB module validation.
# The vpc module owner should own this block in their PR.
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr                = "10.0.0.0/16"
  public_subnet_az1_cidr  = "10.0.1.0/24"
  public_subnet_az2_cidr  = "10.0.2.0/24"
  private_subnet_az1_cidr = "10.0.3.0/24"
  private_subnet_az2_cidr = "10.0.4.0/24"
  eks_cluster_name        = "spc-stg-ue1-eks-main"
}

module "alb" {
  source = "../../modules/alb"

  aws_region             = var.aws_region
  common_tags            = local.common_tags
  domain_name            = var.domain_name

  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_security_group_id  = module.vpc.alb_security_group_id
  cluster_name           = module.eks.cluster_name
  lb_controller_role_arn = module.iam.lb_controller_role_arn
  acm_certificate_arn    = var.acm_certificate_arn
}

module "dns" {
  source = "../../modules/dns"

  aws_region          = var.aws_region
  domain_name         = var.domain_name
  staging_alb_name    = var.staging_alb_name
  prod_alb_name       = var.prod_alb_name
  create_prod_records = var.create_prod_records
  default_tags        = var.default_tags
}