variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs for public subnets (must align with public_subnet_cidrs)"
  type        = list(string)
}

variable "tags" {
  description = "Additional tags to merge into every resource"
  type        = map(string)
  default     = {}
}
