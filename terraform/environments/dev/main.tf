terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  # backend "s3" is configured in backend.tf
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "petclinic"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# Exec-based auth for the kubernetes/helm providers. Re-generates a fresh EKS
# token on every API call (via the local aws CLI), so long-running applies
# never hit the 15-minute token-expiry wall that plagues the data-source approach.
# Requires `aws` CLI on the machine running terraform.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.aws_region,
      ]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region,
    ]
  }
}

# ── EKS access entry for the principal running terraform ────────────────────
# Cluster was created with authentication_mode = API_AND_CONFIG_MAP, which
# means the creator does NOT automatically get cluster-admin (unlike legacy
# CONFIG_MAP mode). We need an explicit access entry, otherwise the Helm
# provider gets "server has asked for the client to provide credentials".
data "aws_caller_identity" "current" {}

locals {
  caller_arn = data.aws_caller_identity.current.arn

  # If terraform is run with an assumed role, caller_arn looks like:
  #   arn:aws:sts::123456789012:assumed-role/RoleName/SessionName
  # EKS access entries take the role ARN, not the session ARN. Transform.
  caller_is_assumed_role = can(regex("^arn:aws:sts::[0-9]+:assumed-role/", local.caller_arn))
  caller_principal_arn = local.caller_is_assumed_role ? format(
    "arn:aws:iam::%s:role/%s",
    data.aws_caller_identity.current.account_id,
    split("/", local.caller_arn)[1]
  ) : local.caller_arn
}

resource "aws_eks_access_entry" "tf_caller" {
  cluster_name  = module.eks.cluster_name
  principal_arn = local.caller_principal_arn
  type          = "STANDARD"

  tags = {
    Purpose = "terraform-local-admin"
  }
}

resource "aws_eks_access_policy_association" "tf_caller_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = local.caller_principal_arn
  # EKS access policies live under the eks:: ARN namespace, NOT iam:: —
  # AmazonEKSClusterAdminPolicy is the cluster-wide admin built-in.
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.tf_caller]
}

locals {
  environment = "dev"
  services = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "visits-service",
    "vets-service",
    "genai-service",
    "admin-server",
    "db-migrations", # Flyway image — built from spring-petclinic-microservices/db/migrations/
  ]
}

module "vpc" {
  source = "../../modules/vpc"

  project             = "petclinic"
  environment         = local.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "eks" {
  source = "../../modules/eks"

  project             = "petclinic"
  environment         = local.environment
  cluster_version     = var.cluster_version
  subnet_ids          = module.vpc.public_subnet_ids
  cluster_sg_id       = module.vpc.eks_cluster_sg_id
  node_sg_id          = module.vpc.eks_node_sg_id
  node_instance_types = ["t4g.small"]
  node_ami_type       = "AL2_ARM_64"
  node_min_size       = 2
  node_max_size       = 4
  node_desired_size   = 2
  node_disk_size      = 20
}

module "ecr" {
  source = "../../modules/ecr"

  project              = "petclinic"
  environment          = local.environment
  service_names        = local.services
  image_tag_mutability = "MUTABLE"
}

module "rds" {
  source = "../../modules/rds"

  project                 = "petclinic"
  environment             = local.environment
  subnet_ids              = module.vpc.public_subnet_ids
  security_group_id       = module.vpc.rds_sg_id
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 20
  multi_az                = false
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false
}

module "secrets" {
  source = "../../modules/secrets"

  project        = "petclinic"
  environment    = local.environment
  openai_api_key = var.openai_api_key
}

module "dns" {
  count  = var.domain_name == "" ? 0 : 1
  source = "../../modules/dns"

  domain_name = var.domain_name
}

module "karpenter" {
  source = "../../modules/karpenter"

  project           = "petclinic"
  environment       = local.environment
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  node_role_arn     = module.eks.node_role_arn
}

# External Secrets Operator — installed via Helm provider so it's ready before
# ArgoCD applications that depend on ExternalSecret CRDs sync. The ESO
# controller assumes the IRSA role created in this module to read
# petclinic/dev/* secrets from AWS Secrets Manager.
module "external_secrets" {
  source = "../../modules/external-secrets"

  environment       = local.environment
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn

  depends_on = [
    module.eks,                                        # node group + EBS CSI add-on Ready
    aws_eks_access_policy_association.tf_caller_admin, # caller needs cluster-admin so helm provider can install
  ]
}

# ── GitHub Actions OIDC + IAM roles ─────────────────────────────────────────
# Two roles, one per repo, both federated to the same GitHub OIDC provider.
# Trust policies pin the sub claim so each repo can only assume its own role.

locals {
  app_repo_subject   = "repo:${var.github_org}/spring-petclinic-microservices:*"
  infra_repo_subject = "repo:${var.github_org}/spring-petclinic-Group-4-infra:*"

  # Tight ECR-push-only policy for the app repo's workflows.
  app_ecr_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushToDev"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/petclinic-dev/*"
      },
    ]
  })
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  create_oidc_provider = var.create_github_oidc_provider

  roles = {
    "petclinic-app-github-actions" = {
      sub_pattern   = local.app_repo_subject
      inline_policy = local.app_ecr_policy
    }
    "petclinic-infra-github-actions" = {
      sub_pattern         = local.infra_repo_subject
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
  }
}
