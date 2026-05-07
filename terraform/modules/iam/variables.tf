# ──────────────────────────────────────────────────────────────
# IAM Module Variables
# Project:  Spring PetClinic Microservices
# Standard: spc-[env]-ue1-iam-[resource]
# ──────────────────────────────────────────────────────────────

variable "environment" {
  description = "Deployment environment (staging or prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID used for OIDC trust policy"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name for OIDC trust"
  type        = string
  default     = "spring-petclinic-Group-4-DMI"
}

variable "github_app_repo" {
  description = "GitHub app repository name for OIDC trust"
  type        = string
  default     = "spring-petclinic-microservices"
}

variable "github_infra_repo" {
  description = "GitHub infra repository name for OIDC trust"
  type        = string
  default     = "spring-petclinic-Group-4-infra"
}

variable "common_tags" {
  description = "Common tags applied to all IAM resources"
  type        = map(string)
  default     = {}
}