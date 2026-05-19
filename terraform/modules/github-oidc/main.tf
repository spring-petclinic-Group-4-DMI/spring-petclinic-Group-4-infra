# Creates the GitHub Actions OIDC identity provider (one per AWS account) plus
# any number of IAM roles that GitHub Actions can assume via web identity
# federation. Each role's trust policy is pinned to a specific repo+ref subject
# pattern, so workflows in one repo can't assume another repo's role.
#
# Reference: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

locals {
  oidc_provider_url      = "token.actions.githubusercontent.com"
  oidc_provider_hostpath = local.oidc_provider_url
  oidc_provider_arn = var.create_oidc_provider ? (
    aws_iam_openid_connect_provider.github[0].arn
    ) : (
    # Auto-discover the existing provider when create_oidc_provider = false.
    # AWS accounts can only have one provider per URL, so this is unambiguous.
    data.aws_iam_openid_connect_provider.existing[0].arn
  )
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://${local.oidc_provider_url}"
}

# AWS keeps the thumbprint up-to-date for this provider, but a non-empty list
# is still required at create time. These are the current GitHub Actions root
# CA SHA-1 fingerprints (both, for graceful rotation).
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.oidc_provider_url}"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = merge(var.tags, {
    Name = "github-actions-oidc"
  })
}

resource "aws_iam_role" "this" {
  for_each = var.roles

  name = each.key

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.oidc_provider_hostpath}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${local.oidc_provider_hostpath}:sub" = each.value.sub_pattern
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name = each.key
  })
}

# Flatten the (role × managed-policy) pairs so for_each gets a stable key.
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    for pair in flatten([
      for role_name, role in var.roles : [
        for policy_arn in coalesce(role.managed_policy_arns, []) : {
          key        = "${role_name}::${policy_arn}"
          role_name  = role_name
          policy_arn = policy_arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.this[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "inline" {
  for_each = {
    for role_name, role in var.roles : role_name => role
    if role.inline_policy != null && role.inline_policy != ""
  }

  name   = "${each.key}-inline"
  role   = aws_iam_role.this[each.key].id
  policy = each.value.inline_policy
}
