terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }
  }

  backend "s3" {
    bucket         = "spc-staging-ue1-tfstate"
    key            = "terraform/vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "spc-staging-ue1-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"

  
}
