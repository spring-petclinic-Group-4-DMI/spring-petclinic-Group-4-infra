
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
