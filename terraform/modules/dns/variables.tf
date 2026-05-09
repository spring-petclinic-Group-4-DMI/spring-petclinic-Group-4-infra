variable "default_tags" {
  description = "Tags applied to the Route53 zone and ACM certificate."
  type        = map(string)
  default = {
    Project   = "spring-petclinic"
    Team      = "group-4"
    ManagedBy = "terraform"
    Epic      = "SPC-005"
  }
}

variable "domain_name" {
  description = "Apex domain name for the hosted zone (e.g. petclinic-group4.com). All DNS records are created as subdomains or the apex of this zone."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-\\.]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a valid lowercase DNS name such as petclinic-group4.com."
  }
}
