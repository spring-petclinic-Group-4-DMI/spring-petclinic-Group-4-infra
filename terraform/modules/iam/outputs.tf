output "github_actions_ci_role_arn" {
  description = "ARN of the GitHub Actions CI role for building and pushing to ECR"
  value       = data.aws_iam_role.github_actions_ci.arn
}

output "terraform_role_arn" {
  description = "ARN of the Terraform role for provisioning infrastructure"
  value       = data.aws_iam_role.terraform.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node role for worker nodes"
  value       = aws_iam_role.eks_node.arn
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster role for the control plane"
  value       = aws_iam_role.eks_cluster.arn
}

