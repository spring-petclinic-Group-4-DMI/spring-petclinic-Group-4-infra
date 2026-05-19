variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name Karpenter will manage nodes for"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN from the EKS module (used for IRSA)"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN attached to Karpenter-launched EC2 nodes"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
