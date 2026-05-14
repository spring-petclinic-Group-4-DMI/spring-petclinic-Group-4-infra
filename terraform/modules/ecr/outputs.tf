output "repository_urls" {
  description = "Map of service name to ECR repository URL."
  value = {
    for svc, repo in aws_ecr_repository.microservices :
    svc => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map of service name to ECR repository ARN."
  value = {
    for svc, repo in aws_ecr_repository.microservices :
    svc => repo.arn
  }
}

output "registry_id" {
  description = "AWS account ID (ECR registry ID)."
  value       = data.aws_caller_identity.current.account_id
}

output "registry_url" {
  description = "Base ECR registry URL."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
}

output "docker_login_command" {
  description = "Command to authenticate Docker to ECR."
  value       = "aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
}