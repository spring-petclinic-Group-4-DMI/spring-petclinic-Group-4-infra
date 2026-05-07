output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_data" {
  description = "EKS cluster CA certificate (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "node_group_status" {
  description = "Node group status"
  value       = aws_eks_node_group.main.status
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — needed by Karpenter and ESO"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
