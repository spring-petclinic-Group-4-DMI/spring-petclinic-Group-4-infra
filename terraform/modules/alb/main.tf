#################################################################################
# 1. APPLICATION LOAD BALANCER
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

resource "aws_lb" "this" {
  # Naming standard: spc-stg-ue1-alb-external
  name               = "spc-stg-ue1-alb-external"
  internal           = false # false = internet-facing
  load_balancer_type = "application"

  # These come from the vpc module (Cloud/Infra Eng 1 — SPC-010-T1 / SPC-010-T2)
  # They are passed in via var.* — nothing is hardcoded here
  security_groups = [var.alb_security_group_id]
  subnets         = var.public_subnet_ids

  drop_invalid_header_fields = true # security best practice

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-alb-external"
  })
}

###############################################################################
# 2. TARGET GROUP
# Terraform owns this target group. The AWS Load Balancer Controller registers
# api-gateway pod IPs into it through the TargetGroupBinding below.
###############################################################################

resource "aws_lb_target_group" "default" {
  name        = "spc-stg-ue1-alb-tg-default"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip" # required for EKS pod-level routing

  # vpc_id comes from the vpc module (Cloud/Infra Eng 1 — SPC-010-T1)
  vpc_id = var.vpc_id

  health_check {
    path                = "/actuator/health" # standard Spring Boot endpoint
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-alb-tg-default"
  })
}

###############################################################################
# 3. HTTP LISTENER — Port 80
# While enable_https=false, this forwards directly to the application so the
# ALB DNS name can be used without a domain. Once the ACM certificate is ready,
# enable_https=true changes this listener back to an HTTP -> HTTPS redirect.
###############################################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.enable_https ? [1] : []
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.default.arn
    }
  }
}

###############################################################################
# 4. HTTPS LISTENER — Port 443
# SSL terminates here using the ACM certificate when enable_https=true.
# Traffic is decrypted at this point and forwarded as plain HTTP internally.
###############################################################################

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  # acm_certificate_arn comes from the DNS module in environments/staging/main.tf.
  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-alb-listener-https"
  })
}

###############################################################################
# 5. LB CONTROLLER — IAM role + policy (IRSA)
#
# The role is defined here (rather than in module.iam) because its trust
# policy needs the EKS OIDC provider, which is created by module.eks.
# Putting it in module.iam would be circular: module.eks consumes module.iam,
# so module.iam can't also depend on module.eks.
#
# Permissions policy is the AWS-recommended policy for the LB Controller
# (vendored from kubernetes-sigs/aws-load-balancer-controller v2.7+).
###############################################################################

data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "spc-stg-ue1-iam-ro-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-iam-ro-lb-controller"
  })
}

resource "aws_iam_policy" "lb_controller" {
  name        = "spc-stg-ue1-iam-policy-lb-controller"
  description = "Permissions for the AWS Load Balancer Controller (kubernetes-sigs/aws-load-balancer-controller v2.7+)"
  policy      = file("${path.module}/lb_controller_policy.json")

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-iam-policy-lb-controller"
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

###############################################################################
# 6. LB CONTROLLER — Kubernetes ServiceAccount
#
# The controller needs a Kubernetes identity (ServiceAccount) to run as.
# The annotation below links it to the IAM role above using IRSA.
###############################################################################

resource "kubernetes_service_account" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }

    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }
}

###############################################################################
# 7. LB CONTROLLER — Helm Release
#
# Installs the controller as a background process inside EKS.
# In this module it is used for TargetGroupBinding reconciliation only; the
# ALB, listeners, and target group remain Terraform-managed.
#
# cluster_name comes from the eks module (Cloud/Infra Eng 2 — SPC-011-T1)
###############################################################################

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_chart_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  # The EKS cluster this controller will manage
  set {
    name  = "clusterName"
    value = var.cluster_name # from eks module
  }

  # Use the ServiceAccount we created above (IRSA already wired via annotation)
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_lb_controller.metadata[0].name
  }

  # 2 replicas so the controller stays up if one pod restarts
  set {
    name  = "replicaCount"
    value = "2"
  }

  # vpc and region so the controller knows where it is
  set {
    name  = "vpcId"
    value = var.vpc_id # from vpc module
  }
  set {
    name  = "region"
    value = var.aws_region
  }

  # Shield and WAF off for staging
  set {
    name  = "enableShield"
    value = "false"
  }
  set {
    name  = "enableWaf"
    value = "false"
  }

  # Resource limits (required by team security checklist — SPC-072)
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }
  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  depends_on = [kubernetes_service_account.aws_lb_controller]
}

###############################################################################
# 8. TARGET GROUP BINDING
#
# Terraform owns the ALB, listeners, DNS alias, and target group. The AWS Load
# Balancer Controller owns only pod target registration through this
# TargetGroupBinding. This avoids the duplicate ALB ownership conflict that
# happens when an Ingress tries to create an ALB with the same name.
###############################################################################

resource "helm_release" "api_gateway_target_group_binding" {
  name      = "api-gateway-target-group-binding"
  chart     = "${path.module}/target-group-binding"
  namespace = var.app_namespace
  wait      = true
  timeout   = 300

  set {
    name  = "name"
    value = "api-gateway"
  }

  set {
    name  = "serviceName"
    value = var.api_gateway_service_name
  }

  set {
    name  = "servicePort"
    value = tostring(var.api_gateway_service_port)
  }

  set {
    name  = "targetGroupArn"
    value = aws_lb_target_group.default.arn
  }

  depends_on = [
    helm_release.aws_lb_controller,
    aws_lb_listener.http,
  ]
}
