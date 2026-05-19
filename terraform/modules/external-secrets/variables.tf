variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev)"
  type        = string
}

variable "aws_region" {
  description = "AWS region (scoped into the Secrets Manager ARN policy)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN from the eks module (used for IRSA federation)"
  type        = string
}

variable "chart_version" {
  description = "external-secrets chart version. Browse: https://github.com/external-secrets/external-secrets/releases"
  type        = string
  default     = "0.10.4"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
