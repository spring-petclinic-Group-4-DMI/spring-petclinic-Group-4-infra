# External Secrets Operator (ESO) install + IRSA wiring.
#
# Installs the upstream chart from charts.external-secrets.io into a dedicated
# namespace and creates an IAM role that the controller pod assumes via IRSA
# (federated through the cluster's OIDC provider). The role has tightly-scoped
# Secrets Manager read permissions on petclinic/{env}/*.
#
# The ClusterSecretStore CR (which tells ESO where to read secrets from) is
# applied by ArgoCD from k8s/base/external-secrets/ — not by this module.
# Splitting it out avoids the CRD chicken-and-egg.

locals {
  name_prefix          = "${var.project}-${var.environment}"
  oidc_provider_path   = replace(var.oidc_provider_arn, "/^.*oidc-provider\\//", "")
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
}

# ── IRSA role for the ESO controller ────────────────────────────────────────

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_path}:sub"
      values   = ["system:serviceaccount:${local.namespace}:${local.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_path}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.name_prefix}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# Tight scope: only petclinic/{env}/* secrets in this account/region.
# Add KMS Decrypt here if you ever move off the default aws/secretsmanager key.
data "aws_iam_policy_document" "read" {
  statement {
    sid = "ReadPetclinicSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:*:secret:petclinic/${var.environment}/*",
    ]
  }
}

resource "aws_iam_role_policy" "read" {
  name   = "${local.name_prefix}-eso-secrets-read"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.read.json
}

# ── Helm release ────────────────────────────────────────────────────────────

resource "helm_release" "this" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version
  namespace        = local.namespace
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode({
    installCRDs = true

    serviceAccount = {
      create = true
      name   = local.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
      }
    }

    # Resource caps so ESO doesn't blow up the tight dev cluster budget.
    resources = {
      requests = { cpu = "50m", memory = "128Mi" }
      limits   = { memory = "256Mi" }
    }

    webhook = {
      resources = {
        requests = { cpu = "30m", memory = "64Mi" }
        limits   = { memory = "128Mi" }
      }
    }

    certController = {
      resources = {
        requests = { cpu = "30m", memory = "64Mi" }
        limits   = { memory = "128Mi" }
      }
    }
  })]

  depends_on = [aws_iam_role_policy.read]
}
