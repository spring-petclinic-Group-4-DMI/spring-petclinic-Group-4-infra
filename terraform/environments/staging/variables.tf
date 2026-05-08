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

variable "aws_region" {
  description = "AWS region for staging resources"
  type        = string
  default     = "us-east-1"
}

variable "repository_prefix" {
  description = "Prefix for ECR repository names"
  type        = string
  default     = "spring-petclinic"
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
###############################################################################
# ALB Module variables — SPC-005-T8
# Add these to environments/staging/variables.tf
###############################################################################

variable "domain_name" {
  description = "Base domain for the app e.g. petclinic.example.com. Used by the ALB module for the Ingress host rule and ACM certificate."
  type        = string
}

variable "staging_alb_name" {
  description = "Name of the staging Application Load Balancer as it appears in the AWS console. This is the Name tag or the name field set in the aws_lb resource in SPC-005-T8."
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for ACM DNS validation. Needed by the ALB module to validate the SSL certificate."
  type        = string
  default     = ""
}

variable "existing_acm_certificate_arn" {
  description = "If an ACM certificate already exists, paste its ARN here. The ALB module will use it instead of creating a new one."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate passed into the ALB module for HTTPS termination on port 443."
  type        = string
  default     = ""
}

# ── Temporary variables — replaced by module outputs once teammates merge ─────
# These exist so you can run terraform plan before other modules are ready.
# Each one has a TODO telling you when to remove it.


variable "app_namespace" {
  description = "Kubernetes namespace where api-gateway is deployed. Confirm with DevOps Eng 2 (SPC-042-T1)."
  type        = string
  default     = "petclinic"
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

# ── RDS Module variables — SPC-39 ────────────────────────────────────────────

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
