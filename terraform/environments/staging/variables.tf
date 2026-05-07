variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "staging"
}

variable "repository_prefix" {
  description = "Prefix for repository names."
  type        = string
  default     = "spring-petclinic"
}