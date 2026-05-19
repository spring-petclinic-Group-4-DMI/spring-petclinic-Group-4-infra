output "karpenter_role_arn" {
  description = "IRSA role ARN for the Karpenter controller service account"
  value       = aws_iam_role.controller.arn
}

output "karpenter_queue_name" {
  description = "SQS queue name for EC2 interruption events"
  value       = aws_sqs_queue.interruption.name
}

output "karpenter_queue_arn" {
  description = "SQS queue ARN for EC2 interruption events"
  value       = aws_sqs_queue.interruption.arn
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name to attach to Karpenter-launched nodes"
  value       = aws_iam_instance_profile.karpenter_node.name
}
