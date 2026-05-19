variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane. NOTE: lifecycle.ignore_changes is set on the cluster resource, so changing this after creation is a no-op — bump the cluster version via the AWS console / CLI instead, then update this for documentation purposes."
  type        = string
  default     = "1.30"
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS cluster and node group"
  type        = list(string)
}

variable "cluster_sg_id" {
  description = "Security group ID attached to the EKS control plane ENIs"
  type        = string
}

variable "node_sg_id" {
  description = "Security group ID for worker nodes (declared per spec; managed node group uses its own SG)"
  type        = string
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t4g.small"]
}

variable "node_ami_type" {
  description = "AMI type for the managed node group (ARM64 = AL2_ARM_64)"
  type        = string
  default     = "AL2_ARM_64"
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Node EBS root volume size in GB"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
