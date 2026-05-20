output "role_arn" {
  description = "IRSA role ARN used by the AWS Load Balancer Controller"
  value       = aws_iam_role.this.arn
}

output "service_account_name" {
  description = "Kubernetes service account used by the controller"
  value       = local.service_account_name
}

output "namespace" {
  description = "Namespace where the controller is installed"
  value       = local.namespace
}
