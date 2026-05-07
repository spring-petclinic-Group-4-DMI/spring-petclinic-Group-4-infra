# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where the ALB and ACM certificate are provisioned. Must match the ALB region — ACM certificates for ALBs are regional (unlike CloudFront which requires us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "default_tags" {
  description = "Tags applied to every resource via the provider default_tags block."
  type        = map(string)
  default = {
    Project     = "spring-petclinic"
    Team        = "group-4"
    ManagedBy   = "terraform"
    Epic        = "SPC-005"
  }
}

# ---------------------------------------------------------------------------
# Domain
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Apex domain name for the hosted zone (e.g. petclinic-group4.com). All DNS records are created as subdomains or the apex of this zone."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-\\.]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a valid lowercase DNS name such as petclinic-group4.com."
  }
}

# ---------------------------------------------------------------------------
# ALB names (used by data sources to look up ALBs from SPC-005-T8)
# ---------------------------------------------------------------------------

variable "staging_alb_name" {
  description = "Name of the staging Application Load Balancer as it appears in the AWS console. This is the Name tag or the name field set in the aws_lb resource in SPC-005-T8."
  type        = string
}

variable "prod_alb_name" {
  description = "Name of the production Application Load Balancer. Only required when create_prod_records is true."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Feature flag — prod records
# ---------------------------------------------------------------------------

variable "create_prod_records" {
  description = "Set to true once the production ALB (prod_alb_name) has been provisioned. When false, only staging.{domain_name} records are created and the prod ALB data source is not looked up, so this module can be applied during Sprint 3 before the prod environment exists."
  type        = bool
  default     = false
}
