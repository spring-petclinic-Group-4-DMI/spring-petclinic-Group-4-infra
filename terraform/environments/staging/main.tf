terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "spring-petclinic-microservices"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Sprint      = "S2-Core-Infrastructure"
      Task        = "SPC-005-T4"
    }
  }
}

module "ecr" {
  source            = "../../modules/ecr"
  aws_region        = var.aws_region
  environment       = var.environment
  repository_prefix = var.repository_prefix
}