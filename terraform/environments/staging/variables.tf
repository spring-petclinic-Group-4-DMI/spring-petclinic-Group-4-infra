variable "aws_region" {
  description = "AWS region for staging resources."
  type        = string
  default     = "us-east-1"
}

variable "project_code" {
  description = "Short project code used in AWS resource names."
  type        = string
  default     = "spc"
}

variable "environment_code" {
  description = "Short environment code used in AWS resource names."
  type        = string
  default     = "stg"
}

variable "region_code" {
  description = "Short region code used in AWS resource names."
  type        = string
  default     = "ue1"
}

variable "secret_component" {
  description = "Component segment in the standard secret name."
  type        = string
  default     = "app"
}

variable "secret_resource_name" {
  description = "Resource segment in the standard secret name."
  type        = string
  default     = "secret"
}

variable "secret_resource_count" {
  description = "Count suffix in the standard secret name."
  type        = string
  default     = "01"
}

variable "db_name" {
  description = "Application database name stored alongside the credentials."
  type        = string
  default     = "petclinic"
}

variable "secret_description" {
  description = "Description for the staging secret bundle."
  type        = string
  default     = "Application secrets for the staging environment."
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key ID or ARN."
  type        = string
  default     = null
}

variable "create_secret_version" {
  description = "Whether Terraform should create the initial secret values."
  type        = bool
  default     = false
}

variable "mysql_username" {
  description = "RDS MySQL username for staging."
  type        = string
  sensitive   = true
}

variable "mysql_password" {
  description = "RDS MySQL password for staging."
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for the GenAI service."
  type        = string
  sensitive   = true
}

variable "additional_secret_values" {
  description = "Any extra secret key-value pairs needed by the platform."
  type        = map(string)
  sensitive   = true
  default     = {}
}
