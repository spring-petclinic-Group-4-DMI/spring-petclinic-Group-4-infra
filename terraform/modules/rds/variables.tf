variable "environment" {
  description = "Deployment environment (stg or prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed — passed from VPC module output"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group — passed from VPC module output"
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group ID of EKS nodes allowed to connect to RDS on port 3306"
  type        = string
}

variable "db_name" {
  description = "Name of the MySQL database to create"
  type        = string
  default     = "petclinic"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "petclinic_admin"
}

variable "db_password" {
  description = "Master password for the RDS instance — injected from Secrets Manager, never hardcoded"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage size in GB for the RDS instance"
  type        = number
  default     = 20
}

variable "common_tags" {
  description = "Common tags applied to all resources for cost tracking and identification"
  type        = map(string)
}
