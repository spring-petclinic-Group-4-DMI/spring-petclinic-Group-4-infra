variable "cluster_name" {
  description = "EKS cluster name — must match the EKS module cluster_name output"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS API server endpoint — from EKS module cluster_endpoint output"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN — from EKS module oidc_provider_arn output"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL — from EKS module oidc_issuer_url output"
  type        = string
}

variable "environment" {
  description = "Deployment environment (stg or prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID — needed to build IAM role ARNs"
  type        = string
}

variable "node_instance_types" {
  description = "List of EC2 instance types Karpenter can provision"
  type        = list(string)
  default     = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
}

variable "node_capacity_type" {
  description = "Capacity type for Karpenter nodes — spot or on-demand"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "common_tags" {
  description = "Common tags applied to all Karpenter resources"
  type        = map(string)
}