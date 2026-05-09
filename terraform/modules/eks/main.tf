locals {
  common_tags = {
    Project     = "Spring PetClinic"
    Environment = "Staging"
    ManagedBy   = "Terraform"
    Owner       = "Group-4-DevOps"
    CostCenter  = "Engineering-Internship"
  }
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids = [
      var.private_subnet_az1_id,
      var.private_subnet_az2_id,
    ]
    security_group_ids      = [var.eks_node_sg_id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode = "API"
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "spc-stg-ue1-eks-ng-main"
  node_role_arn   = var.eks_node_role_arn

  subnet_ids = [
    var.private_subnet_az1_id,
    var.private_subnet_az2_id,
  ]

  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  tags = merge(local.common_tags, {
    Name                     = "spc-stg-ue1-eks-ng-main"
    "karpenter.sh/discovery" = var.cluster_name
  })

  depends_on = [aws_eks_cluster.main]
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-oidc"
  })
}

resource "aws_eks_access_entry" "node_role" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.eks_node_role_arn
  type          = "EC2_LINUX"

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_access_entry" "terraform_role" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::338593158888:role/spc-staging-ue1-iam-ro-terraform"
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_access_policy_association" "terraform_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::338593158888:role/spc-staging-ue1-iam-ro-terraform"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform_role]
}
