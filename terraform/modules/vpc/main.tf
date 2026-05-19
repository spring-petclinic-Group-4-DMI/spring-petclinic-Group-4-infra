locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                         = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/cluster/${local.name_prefix}" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Security Groups ---

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "EKS control plane SG"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-cluster-sg"
  })
}

resource "aws_security_group" "eks_node" {
  name        = "${local.name_prefix}-node-sg"
  description = "EKS worker node SG"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-node-sg"
  })
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS MySQL SG - accepts traffic from EKS nodes only"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB SG - public ingress on 80/443"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# --- Cluster SG rules ---

resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes_443" {
  security_group_id            = aws_security_group.eks_cluster.id
  referenced_security_group_id = aws_security_group.eks_node.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "API server from nodes"
}

resource "aws_vpc_security_group_egress_rule" "cluster_all_egress" {
  security_group_id = aws_security_group.eks_cluster.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All egress"
}

# --- Node SG rules ---

resource "aws_vpc_security_group_ingress_rule" "node_from_cluster_all" {
  security_group_id            = aws_security_group.eks_node.id
  referenced_security_group_id = aws_security_group.eks_cluster.id
  ip_protocol                  = "-1"
  description                  = "All from cluster SG"
}

resource "aws_vpc_security_group_ingress_rule" "node_self" {
  security_group_id            = aws_security_group.eks_node.id
  referenced_security_group_id = aws_security_group.eks_node.id
  ip_protocol                  = "-1"
  description                  = "Inter-node communication"
}

resource "aws_vpc_security_group_ingress_rule" "node_kubelet_from_cluster" {
  security_group_id            = aws_security_group.eks_node.id
  referenced_security_group_id = aws_security_group.eks_cluster.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Kubelet API from cluster"
}

resource "aws_vpc_security_group_ingress_rule" "node_nodeport_from_alb" {
  security_group_id            = aws_security_group.eks_node.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  description                  = "NodePort services from ALB"
}

resource "aws_vpc_security_group_egress_rule" "node_all_egress" {
  security_group_id = aws_security_group.eks_node.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All egress"
}

# --- RDS SG rules ---

resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.eks_node.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL from EKS nodes only"
}

# --- ALB SG rules ---

resource "aws_vpc_security_group_ingress_rule" "alb_http_internet" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTP from internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_internet" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTPS from internet"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes_nodeport" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.eks_node.id
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  description                  = "Target group traffic to NodePort range"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes_healthcheck" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.eks_node.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  description                  = "Health checks to nodes"
}
