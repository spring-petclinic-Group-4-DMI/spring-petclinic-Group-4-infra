variable "aws_region" {
  description = "AWS region where ECR repositories will be created."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "repository_prefix" {
  description = "Optional prefix for all repository names."
  type        = string
  default     = "spring-petclinic"
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE image tags."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Must be MUTABLE or IMMUTABLE."
  }
}

variable "encryption_type" {
  description = "AES256 or KMS encryption."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "Must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN (only needed if encryption_type is KMS)."
  type        = string
  default     = null
}

variable "max_image_count" {
  description = "Max tagged images to keep per repository."
  type        = number
  default     = 10
}