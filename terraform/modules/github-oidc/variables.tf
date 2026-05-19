variable "create_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false if it already exists in this AWS account (only one per account is allowed) — the module will auto-discover it via data source."
  type        = bool
  default     = true
}

variable "roles" {
  description = <<-EOT
    Map of IAM role name → role specification.

    Each role can attach a list of AWS-managed policy ARNs and/or a single
    JSON-encoded inline policy. The trust policy is pinned to sub_pattern,
    which should be a GitHub Actions subject claim like:
      - "repo:my-org/my-repo:ref:refs/heads/main"
      - "repo:my-org/my-repo:environment:dev"
      - "repo:my-org/my-repo:*"      (any ref/env in that repo — broadest)
  EOT
  type = map(object({
    sub_pattern         = string
    managed_policy_arns = optional(list(string))
    inline_policy       = optional(string)
  }))
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
