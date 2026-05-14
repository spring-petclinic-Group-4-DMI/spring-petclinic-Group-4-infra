terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
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
}

module "iam" {
  source = "../modules/iam"

  environment                        = "staging"
  aws_account_id                     = "428101261622"
  github_org                         = "spring-petclinic-Group-4-DMI"
  github_actions_secret_arns         = []
  github_actions_ecr_repository_arns = []
  common_tags                        = {}
}
