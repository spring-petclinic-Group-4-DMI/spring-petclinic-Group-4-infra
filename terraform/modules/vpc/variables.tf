variable "vpc_cidr" {
  description = "CIDR block for the main VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_az1_cidr" {
  description = "CIDR for public subnet in us-east-1a."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_az2_cidr" {
  description = "CIDR for public subnet in us-east-1b."
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_az1_cidr" {
  description = "CIDR for private subnet in us-east-1a."
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_az2_cidr" {
  description = "CIDR for private subnet in us-east-1b."
  type        = string
  default     = "10.0.4.0/24"
}

variable "eks_cluster_name" {
  description = "EKS cluster name for subnet tags. Confirm with Yassin."
  type        = string
  default     = "spc-stg-ue1-eks-main"
}
