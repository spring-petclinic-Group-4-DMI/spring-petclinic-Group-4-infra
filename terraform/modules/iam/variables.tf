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

variable "github_actions_secret_arns" {
  description = "Secrets Manager secret ARNs the GitHub Actions CI role can read."
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags applied to all IAM resources"
  type        = map(string)
  default     = {}
}
variable "github_actions_ecr_repository_arns" {
  description = "ECR repository ARNs GitHub Actions can push/pull."
  type        = list(string)
  default     = []
}
