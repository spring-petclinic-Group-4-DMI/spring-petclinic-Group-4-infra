variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR block (dev = 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "AZs for public subnets (must align with public_subnet_cidrs)"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane (lifecycle.ignore_changes is set in the module — see eks variables for details)"
  type        = string
  default     = "1.30"
}

variable "domain_name" {
  description = "Apex domain for Route 53 + ACM. Leave empty to skip the dns module."
  type        = string
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key value for genai-service"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_org" {
  description = "GitHub org or user that owns both the app and infra repos. Trust policies pin the sub claim to this owner."
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false if it already exists in this AWS account (one per account)."
  type        = bool
  default     = true
}
