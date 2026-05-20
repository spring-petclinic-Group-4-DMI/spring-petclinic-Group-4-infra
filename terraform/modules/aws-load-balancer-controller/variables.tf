variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the controller creates load balancers"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN from the EKS module"
  type        = string
}

variable "chart_version" {
  description = "aws-load-balancer-controller Helm chart version"
  type        = string
  default     = "3.3.0"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
