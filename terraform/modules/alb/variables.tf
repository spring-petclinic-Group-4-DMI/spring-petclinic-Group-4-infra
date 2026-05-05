variable "vpc_id" {
  description = "VPC ID where the ALB target group is created. Comes from the vpc module (Cloud/Infra Eng 1 — SPC-010-T1)."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of 3 public subnet IDs (one per AZ) where the ALB is placed. Comes from the vpc module. Must be tagged kubernetes.io/role/elb=1 by Cloud/Infra Eng 1."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB. Must allow inbound 80 and 443. Created by Cloud/Infra Eng 1 in SPC-010-T2."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM TLS certificate for HTTPS termination on port 443. Created in environments/staging/main.tf and passed in here."
  type        = string
}

variable "common_tags" {
  description = "Mandatory project tags applied to every resource. Passed in from the staging environment."
  type        = map(string)
}