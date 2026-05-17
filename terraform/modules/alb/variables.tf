###############################################################################
# modules/alb/variables.tf
#
# Every value this module needs is declared here.
# None of these have values — they are all supplied by whoever
# calls this module in environments/staging/main.tf
###############################################################################

# ── General ──────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region. Always us-east-1 for this project."
  type        = string
}

variable "common_tags" {
  description = "Mandatory project tags applied to every AWS resource. Passed in from the staging environment locals block."
  type        = map(string)
}

# ── From vpc module (Cloud/Infra Eng 1 — SPC-010-T1 / SPC-010-T2) ────────────

variable "vpc_id" {
  description = "ID of the VPC. Used by the target group and the LB Controller. Comes from the vpc module output."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (one per AZ) where the ALB is placed. Must be tagged kubernetes.io/role/elb=1 — this is Cloud/Infra Eng 1's responsibility."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB. Must allow inbound 80 and 443 from 0.0.0.0/0. Created by Cloud/Infra Eng 1 in SPC-010-T2."
  type        = string
}

# ── From eks module (Cloud/Infra Eng 2 — SPC-011-T1) ─────────────────────────

variable "cluster_name" {
  description = "EKS cluster name. Used by the Helm chart so the LB Controller knows which cluster it manages. Comes from the eks module output."
  type        = string
}

# ── From eks module (OIDC inputs needed to build the LB-controller IRSA role) ─

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster. Pass module.eks.oidc_issuer_url from the root."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider. Pass module.eks.oidc_provider_arn from the root."
  type        = string
}

# ── SSL certificate ───────────────────────────────────────────────────────────

variable "acm_certificate_arn" {
  description = "ARN of the ACM TLS certificate for HTTPS on port 443. Passed in from whoever manages the cert in the staging environment."
  type        = string
}

variable "enable_https" {
  description = "Whether to create the HTTPS listener and redirect HTTP to HTTPS. Keep false until the domain and ACM certificate are ready."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Base domain for the app e.g. petclinic.example.com. Kept for compatibility with the staging module interface; DNS alias records are managed in the root module."
  type        = string
}

# ── Kubernetes / App ─────────────────────────────────────────────────────────

variable "app_namespace" {
  description = "Kubernetes namespace where api-gateway is deployed. Confirm with DevOps Eng 2 (SPC-042-T1). Default is petclinic."
  type        = string
  default     = "petclinic"
}

variable "api_gateway_service_name" {
  description = "Kubernetes Service name for api-gateway. Must match the Helm rendered Service name."
  type        = string
  default     = "api-gateway"
}

variable "api_gateway_service_port" {
  description = "Port the api-gateway Service listens on. Spring Boot default is 8080."
  type        = number
  default     = 8080
}

variable "lb_controller_chart_version" {
  description = "Pinned Helm chart version for the AWS Load Balancer Controller. Only change this if there is a security advisory."
  type        = string
  default     = "1.7.1"
}
