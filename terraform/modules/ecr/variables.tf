variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev)"
  type        = string
}

variable "service_names" {
  description = "Service names — one ECR repo per service"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Tag mutability: MUTABLE for the dev environment"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
