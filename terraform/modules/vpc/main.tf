locals {
  common_tags = {
    Project     = "Spring PetClinic"
    Environment = "Staging"
    ManagedBy   = "Terraform"
    Owner       = "Group-4-DevOps"
    CostCenter  = "Engineering-Internship"
  }
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name                                            = "spc-stg-ue1-vpc-main"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_az1_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                            = "spc-stg-ue1-az1-sn-public"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_az2_cidr
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                            = "spc-stg-ue1-az2-sn-public"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private_az1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_az1_cidr
  availability_zone = "us-east-1a"

  tags = merge(local.common_tags, {
    Name                                            = "spc-stg-ue1-az1-sn-private"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_az2_cidr
  availability_zone = "us-east-1b"

  tags = merge(local.common_tags, {
    Name                                            = "spc-stg-ue1-az2-sn-private"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = merge(local.common_tags, { Name = "spc-stg-ue1-vpc-igw" })
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main_igw]
  tags       = merge(local.common_tags, { Name = "spc-stg-ue1-vpc-eip-nat" })
}

resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_az1.id
  depends_on    = [aws_internet_gateway.main_igw]
  tags          = merge(local.common_tags, { Name = "spc-stg-ue1-vpc-nat" })
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  tags = merge(local.common_tags, { Name = "spc-stg-ue1-vpc-rt-public" })
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat.id
  }
  tags = merge(local.common_tags, { Name = "spc-stg-ue1-vpc-rt-private" })
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "alb_sg" {
  name        = "spc-stg-ue1-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "spc-stg-ue1-alb-sg" })
}

resource "aws_security_group" "eks_nodes_sg" {
  name        = "spc-stg-ue1-eks-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    description = "Pod-to-pod communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  ingress {
    description = "EKS control plane to nodes"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "spc-stg-ue1-eks-sg" })
}
