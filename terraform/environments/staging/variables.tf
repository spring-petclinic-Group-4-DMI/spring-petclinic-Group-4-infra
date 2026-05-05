# ──────────────────────────────────────────────────────────────
# Staging Environment Variables
# Project:  Spring PetClinic Microservices
# ──────────────────────────────────────────────────────────────

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "staging"
}

variable "aws_account_id" {
  description = "AWS Account ID for IAM role ARN construction"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name for OIDC trust policy"
  type        = string
  default     = "spring-petclinic-Group-4-DMI"
}