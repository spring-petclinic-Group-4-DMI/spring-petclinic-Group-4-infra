variable "project_code" {
  description = "Short project code used in AWS resource names, for example spc."
  type        = string
}

variable "environment_code" {
  description = "Short environment code used in AWS resource names, for example stg or prod."
  type        = string
}

variable "region_code" {
  description = "Short region code used in AWS resource names, for example ue1."
  type        = string
}

variable "description" {
  description = "Description for the Secrets Manager secret."
  type        = string
  default     = "Application secrets stored in AWS Secrets Manager."
}

variable "component" {
  description = "Component segment in the standard resource name."
  type        = string
  default     = "app"
}

variable "resource_name" {
  description = "Resource segment in the standard resource name."
  type        = string
  default     = "secret"
}

variable "resource_count" {
  description = "Count suffix used in the standard resource name."
  type        = string
  default     = "01"
}

variable "recovery_window_in_days" {
  description = "Recovery window before a deleted secret is permanently removed. Set to 0 for immediate deletion on destroy."
  type        = number
  default     = 0
}

variable "kms_key_id" {
  description = "Optional KMS key ID or ARN used to encrypt the secret."
  type        = string
  default     = null
}

variable "secret_values" {
  description = "Map of sensitive key-value pairs to store in the secret."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "create_secret_version" {
  description = "Whether Terraform should create the initial secret value version."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the secret."
  type        = map(string)
  default     = {}
}
