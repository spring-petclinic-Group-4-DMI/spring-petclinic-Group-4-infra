output "karpenter_controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role — used in Helm values"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile name for Karpenter provisioned nodes"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "karpenter_interruption_queue_url" {
  description = "SQS queue URL for spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.url
}