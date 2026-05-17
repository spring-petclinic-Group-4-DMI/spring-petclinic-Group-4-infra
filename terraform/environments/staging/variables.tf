# ──────────────────────────────────────────────────────────────
# Staging Environment Variables
# ──────────────────────────────────────────────────────────────

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "staging"
}

variable "aws_account_id" {
  description = "AWS Account ID for IAM role ARN construction"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be exactly 12 digits. Check the AWS_ACCOUNT_ID GitHub secret."
  }
}

variable "github_org" {
  description = "GitHub organization name for OIDC trust policy"
  type        = string
  default     = "spring-petclinic-Group-4-DMI"
}

variable "aws_region" {
  description = "AWS region for staging resources"
  type        = string
  default     = "us-east-1"
}

variable "repository_prefix" {
  description = "Prefix for ECR repository names. Leave empty so repos are named e.g. 'customers-service' to match the image references in helm/*/values.yaml."
  type        = string
  default     = ""
}

variable "project_code" {
  description = "Short project code used in AWS resource names"
  type        = string
  default     = "spc"
}

variable "environment_code" {
  description = "Short environment code used in AWS resource names"
  type        = string
  default     = "stg"
}

variable "region_code" {
  description = "Short region code used in AWS resource names"
  type        = string
  default     = "ue1"
}

variable "secret_component" {
  description = "Component segment in the standard secret name"
  type        = string
  default     = "app"
}

variable "secret_resource_name" {
  description = "Resource segment in the standard secret name"
  type        = string
  default     = "secret"
}

variable "secret_resource_count" {
  description = "Count suffix in the standard secret name"
  type        = string
  default     = "01"
}

variable "db_name" {
  description = "Application database name stored alongside the credentials"
  type        = string
  default     = "petclinic"
}

variable "secret_description" {
  description = "Description for the staging secret bundle"
  type        = string
  default     = "Application secrets for the staging environment"
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key ID or ARN"
  type        = string
  default     = null
}

variable "create_secret_version" {
  description = "Whether Terraform should create the initial secret values"
  type        = bool
  default     = false
}

variable "mysql_username" {
  description = "RDS MySQL username for staging"
  type        = string
  sensitive   = true
}

variable "mysql_password" {
  description = "RDS MySQL password for staging"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for the GenAI service"
  type        = string
  sensitive   = true
}

variable "additional_secret_values" {
  description = "Any extra secret key-value pairs needed by the platform"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "app_namespace" {
  description = "Kubernetes namespace where api-gateway is deployed. Must match argocd/applications/*.yaml destination.namespace."
  type        = string
  default     = "petclinic-staging"
}

variable "api_gateway_service_name" {
  description = "Kubernetes Service name for api-gateway. Must match exactly what DevOps Eng 2 used in their Helm chart."
  type        = string
  default     = "api-gateway"
}

variable "api_gateway_service_port" {
  description = "Port the api-gateway Service listens on. Spring Boot default is 8080."
  type        = number
  default     = 8080
}

variable "lb_controller_chart_version" {
  description = "Pinned Helm chart version for the AWS Load Balancer Controller. Only change if there is a security advisory."
  type        = string
  default     = "1.7.1"
}

variable "metrics_server_chart_version" {
  description = "Pinned Helm chart version for metrics-server, required by Kubernetes HPAs."
  type        = string
  default     = "3.13.0"
}

# ── RDS Module variables ─────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance type for staging MySQL database"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage size in GB for the staging RDS instance"
  type        = number
  default     = 20
}

variable "domain_name" {
  description = "Base domain for the app e.g. petclinic-group4.com. Used by the DNS module for the hosted zone and ACM certificate."
  type        = string
}

variable "enable_https" {
  description = "Whether to create the ALB HTTPS listener and redirect HTTP to HTTPS. Keep false until the domain and ACM certificate are ready."
  type        = bool
  default     = false
}

# ── EKS cluster name — needed by ALB module ─────────────────────────────────
variable "cluster_name" {
  description = "EKS cluster name — must match what the EKS module creates"
  type        = string
  default     = "spc-stg-ue1-eks-main"
}

variable "default_tags" {
  description = "Default tags applied by the DNS module to the hosted zone and ACM certificate"
  type        = map(string)
  default     = {}
}
