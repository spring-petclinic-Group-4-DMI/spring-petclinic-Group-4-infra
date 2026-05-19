variable "domain_name" {
  description = "Apex domain for the Route 53 hosted zone and wildcard ACM certificate"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
