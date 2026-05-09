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

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster — from EKS module output"
  type        = string
  default     = ""
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider — from EKS module output"
  type        = string
  default     = ""
}