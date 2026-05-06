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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  microservices = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "genai-service",
    "admin-server",
    "frontend",
  ]

  repo_names = {
    for svc in local.microservices :
    svc => var.repository_prefix != "" ? "${var.repository_prefix}/${svc}" : svc
  }
}

resource "aws_ecr_repository" "microservices" {
  for_each             = local.repo_names
  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  tags = {
    Service = each.key
  }
}

resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last ${var.max_image_count} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = { type = "expire" }
      }
    ]
  })
}

data "aws_iam_policy_document" "ecr_repo_policy" {
  statement {
    sid    = "AllowAccountPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

resource "aws_ecr_repository_policy" "microservices" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name
  policy     = data.aws_iam_policy_document.ecr_repo_policy.json
}

# ── Import blocks (Terraform 1.5+) ─────────────────────────────────────────
# These tell Terraform to adopt the existing ECR repositories into state
# instead of trying to create them fresh. Safe to remove after first apply.

import {
  to = aws_ecr_repository.microservices["admin-server"]
  id = "spring-petclinic/admin-server"
}

import {
  to = aws_ecr_repository.microservices["api-gateway"]
  id = "spring-petclinic/api-gateway"
}

import {
  to = aws_ecr_repository.microservices["config-server"]
  id = "spring-petclinic/config-server"
}

import {
  to = aws_ecr_repository.microservices["customers-service"]
  id = "spring-petclinic/customers-service"
}

import {
  to = aws_ecr_repository.microservices["discovery-server"]
  id = "spring-petclinic/discovery-server"
}

import {
  to = aws_ecr_repository.microservices["frontend"]
  id = "spring-petclinic/frontend"
}

import {
  to = aws_ecr_repository.microservices["genai-service"]
  id = "spring-petclinic/genai-service"
}

import {
  to = aws_ecr_repository.microservices["vets-service"]
  id = "spring-petclinic/vets-service"
}

import {
  to = aws_ecr_repository.microservices["visits-service"]
  id = "spring-petclinic/visits-service"
}