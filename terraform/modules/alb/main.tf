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
# Required so the HTTPS listener has a valid default destination.
# The LB Controller creates its own target groups from the Ingress rules,
# but AWS requires a default one for the listener to be created.
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
# Does not serve any content.
# Its only job is to redirect every HTTP request to HTTPS (301 redirect).
###############################################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

###############################################################################
# 4. HTTPS LISTENER — Port 443
# SSL terminates here using the ACM certificate.
# Traffic is decrypted at this point and forwarded as plain HTTP internally.
###############################################################################

# resource "aws_lb_listener" "https" {
#  load_balancer_arn = aws_lb.this.arn
#  port              = 443
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

# acm_certificate_arn comes from whoever manages the ACM cert
# (either Cloud/Infra Eng 1 or created in environments/staging/main.tf)
#  certificate_arn = var.acm_certificate_arn

#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.default.arn
#  }

#  tags = merge(var.common_tags, {
#    Name = "spc-stg-ue1-alb-listener-https"
#  })
#}

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
# Once running, it watches for Ingress resources and automatically
# creates and configures the ALB in AWS.
#
# cluster_name comes from the eks module (Cloud/Infra Eng 2 — SPC-011-T1)
###############################################################################

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_chart_version
  namespace  = "kube-system"

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
# 8. KUBERNETES INGRESS
#
# This tells the LB Controller exactly how to configure the ALB:
# which subnets, which certificate, which ports, and where to send traffic.
#
# The backend service (api-gateway) is deployed by DevOps Eng 2 (SPC-042-T1).
# The service name and namespace must match their Helm chart exactly.
###############################################################################

resource "kubernetes_ingress_v1" "api_gateway" {
  metadata {
    name      = "spc-stg-ue1-api-gateway-ingress"
    namespace = var.app_namespace # confirm with DevOps Eng 2

    annotations = {
      # Create an internet-facing ALB
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"

      # Subnets and security group — from vpc module
      "alb.ingress.kubernetes.io/subnets"         = join(",", var.public_subnet_ids)
      "alb.ingress.kubernetes.io/security-groups" = var.alb_security_group_id

      # SSL certificate and redirect HTTP → HTTPS
      "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
      "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"

      # Open both ports on the ALB
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
        { "HTTP" = 80 },
        { "HTTPS" = 443 }
      ])

      # Spring Boot health check
      "alb.ingress.kubernetes.io/healthcheck-path" = "/actuator/health"

      # ALB name as it appears in the AWS Console
      "alb.ingress.kubernetes.io/load-balancer-name" = "spc-stg-ue1-alb-external"

      # Propagate mandatory project tags to the ALB in AWS
      "alb.ingress.kubernetes.io/tags" = join(",", [
        for k, v in var.common_tags : "${k}=${v}"
      ])
    }
  }

  spec {
    rule {
      host = "staging.${var.domain_name}"


      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              # Must match the Service name in DevOps Eng 2's Helm chart (SPC-042-T1)
              name = var.api_gateway_service_name
              port {
                number = var.api_gateway_service_port
              }
            }
          }
        }
      }
    }
  }

  # Ingress must be created after the controller is running
  depends_on = [helm_release.aws_lb_controller]
}
