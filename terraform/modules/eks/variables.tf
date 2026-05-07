variable "cluster_name" {
  description = "EKS cluster name. Must match kubernetes.io/cluster tag on VPC subnets."
  type        = string
  default     = "spc-stg-ue1-eks-main"
}

variable "vpc_id" {
  description = "VPC ID from SPC-37 output"
  type        = string
  default     = "vpc-045b17957671efbd8"
}

variable "private_subnet_az1_id" {
  description = "Private subnet AZ1 from SPC-37 output"
  type        = string
  default     = "subnet-0db6745d937219f02"
}

variable "private_subnet_az2_id" {
  description = "Private subnet AZ2 from SPC-37 output"
  type        = string
  default     = "subnet-021a1b2ea0fbbe9f2"
}

variable "eks_node_sg_id" {
  description = "EKS nodes security group from SPC-37 output"
  type        = string
  default     = "sg-0427cea744ccd5615"
}

variable "eks_cluster_role_arn" {
  description = "IAM role ARN for EKS control plane"
  type        = string
  default     = "arn:aws:iam::338593158888:role/spc-staging-ue1-iam-ro-eks-cluster"
}

variable "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  type        = string
  default     = "arn:aws:iam::338593158888:role/spc-staging-ue1-iam-ro-eks-node"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}
