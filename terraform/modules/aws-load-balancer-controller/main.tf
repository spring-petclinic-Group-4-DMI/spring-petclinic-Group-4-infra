# AWS Load Balancer Controller install + IRSA wiring.
# The controller watches Kubernetes Ingress resources and provisions ALBs.

locals {
  name_prefix          = "${var.project}-${var.environment}"
  oidc_provider_path   = replace(var.oidc_provider_arn, "/^.*oidc-provider\\//", "")
  namespace            = "kube-system"
  service_account_name = "aws-load-balancer-controller"
}

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
  name               = "${local.name_prefix}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  name        = "${local.name_prefix}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller in ${local.name_prefix}"
  policy      = file("${path.module}/iam-policy.json")
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = local.namespace
  wait       = true
  timeout    = 600

  values = [yamlencode({
    clusterName  = var.cluster_name
    region       = var.aws_region
    vpcId        = var.vpc_id
    replicaCount = 1

    serviceAccount = {
      create = true
      name   = local.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
      }
    }

    enableServiceMutatorWebhook = false

    resources = {
      requests = { cpu = "50m", memory = "128Mi" }
      limits   = { memory = "256Mi" }
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.this]
}
