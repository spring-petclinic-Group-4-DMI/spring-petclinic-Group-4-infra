locals {
  name_prefix         = "${var.project}-${var.environment}"
  oidc_provider_path  = replace(var.oidc_provider_arn, "/^.*oidc-provider\\//", "")
  karpenter_namespace = "kube-system"
  karpenter_sa_name   = "karpenter"
}

# --- SQS queue for EC2 interruption notices ---

resource "aws_sqs_queue" "interruption" {
  name                      = "${local.name_prefix}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

data "aws_iam_policy_document" "interruption_queue" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption.arn]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "sqs.amazonaws.com",
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id
  policy    = data.aws_iam_policy_document.interruption_queue.json
}

# --- EventBridge rules → SQS ---

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${local.name_prefix}-karpenter-spot-interruption"
  description = "EC2 Spot interruption warnings → Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  name        = "${local.name_prefix}-karpenter-rebalance"
  description = "EC2 instance rebalance recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "state_change" {
  name        = "${local.name_prefix}-karpenter-state-change"
  description = "EC2 instance state-change notifications"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "health" {
  name        = "${local.name_prefix}-karpenter-health"
  description = "AWS Health events affecting EC2 instances"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "to_sqs" {
  for_each = {
    spot   = aws_cloudwatch_event_rule.spot_interruption.name
    rebal  = aws_cloudwatch_event_rule.rebalance.name
    state  = aws_cloudwatch_event_rule.state_change.name
    health = aws_cloudwatch_event_rule.health.name
  }

  rule      = each.value
  target_id = "karpenter"
  arn       = aws_sqs_queue.interruption.arn
}

# --- IRSA role for the Karpenter controller ---

data "aws_iam_policy_document" "controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_path}:sub"
      values   = ["system:serviceaccount:${local.karpenter_namespace}:${local.karpenter_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_path}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "controller" {
  name               = "${local.name_prefix}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.controller_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "controller" {
  statement {
    sid = "EC2NodeLifecycle"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateTags",
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassNodeRole"
    actions   = ["iam:PassRole"]
    resources = [var.node_role_arn]
  }

  statement {
    sid = "InterruptionQueue"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.interruption.arn]
  }

  statement {
    sid       = "ClusterRead"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:*:*:cluster/${var.cluster_name}"]
  }

  statement {
    sid       = "PricingRead"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "controller" {
  name   = "${local.name_prefix}-karpenter-controller"
  role   = aws_iam_role.controller.id
  policy = data.aws_iam_policy_document.controller.json
}

# --- Instance profile attached to Karpenter-provisioned nodes ---

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${local.name_prefix}-karpenter-node-profile"
  role = element(split("/", var.node_role_arn), length(split("/", var.node_role_arn)) - 1)
  tags = var.tags
}
