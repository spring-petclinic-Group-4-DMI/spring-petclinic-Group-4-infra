# ──────────────────────────────────────────────────────────────
# Staging Environment - Main
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  backend "s3" {
    bucket         = "spc-staging-ue1-tfstate"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "spc-staging-ue1-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}


locals {
  common_tags = {
    Project     = "Spring PetClinic"
    Environment = "Staging"
    ManagedBy   = "Terraform"
    Owner       = "Group-4-DevOps"
    CostCenter  = "Engineering-Internship"
  }

  app_secret_values = merge(
    {
      MYSQL_USERNAME = var.mysql_username
      MYSQL_PASSWORD = var.mysql_password
      OPENAI_API_KEY = var.openai_api_key
      DB_NAME        = var.db_name
    },
    var.additional_secret_values
  )
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      args = [
        "--kubelet-preferred-address-types=InternalIP",
        "--kubelet-use-node-status-port",
      ]
    })
  ]

  depends_on = [module.eks]
}

module "iam" {
  source = "../../modules/iam"

  environment                        = var.environment
  aws_account_id                     = var.aws_account_id
  github_org                         = var.github_org
  github_actions_secret_arns         = [module.app_secrets.secret_arn]
  github_actions_ecr_repository_arns = values(module.ecr.repository_arns)
  common_tags                        = local.common_tags
}

module "ecr" {
  source            = "../../modules/ecr"
  aws_region        = var.aws_region
  environment       = var.environment
  repository_prefix = var.repository_prefix
}

module "app_secrets" {
  source                = "../../modules/secrets"
  project_code          = var.project_code
  environment_code      = var.environment_code
  region_code           = var.region_code
  component             = var.secret_component
  resource_name         = var.secret_resource_name
  resource_count        = var.secret_resource_count
  description           = var.secret_description
  kms_key_id            = var.kms_key_id
  create_secret_version = var.create_secret_version
  secret_values         = local.app_secret_values
  tags                  = local.common_tags
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr                = "10.0.0.0/16"
  public_subnet_az1_cidr  = "10.0.1.0/24"
  public_subnet_az2_cidr  = "10.0.2.0/24"
  private_subnet_az1_cidr = "10.0.3.0/24"
  private_subnet_az2_cidr = "10.0.4.0/24"
  eks_cluster_name        = "spc-stg-ue1-eks-main"
}

module "eks" {
  source = "../../modules/eks"

  cluster_name          = var.cluster_name
  vpc_id                = module.vpc.vpc_id
  private_subnet_az1_id = module.vpc.private_subnet_az1_id
  private_subnet_az2_id = module.vpc.private_subnet_az2_id
  eks_node_sg_id        = module.vpc.eks_node_sg_id
  eks_cluster_role_arn  = module.iam.eks_cluster_role_arn
  eks_node_role_arn     = module.iam.eks_node_role_arn
  terraform_role_arn    = module.iam.terraform_role_arn

  depends_on = [module.iam]
}

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
  environment       = var.environment_code
  aws_account_id    = var.aws_account_id
  common_tags       = local.common_tags
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }

  depends_on = [module.eks]
}


module "alb" {
  source = "../../modules/alb"

  aws_region                  = var.aws_region
  common_tags                 = local.common_tags
  domain_name                 = var.domain_name
  vpc_id                      = module.vpc.vpc_id
  public_subnet_ids           = module.vpc.public_subnet_ids
  alb_security_group_id       = module.vpc.alb_security_group_id
  cluster_name                = module.eks.cluster_name
  oidc_issuer_url             = module.eks.oidc_issuer_url
  oidc_provider_arn           = module.eks.oidc_provider_arn
  acm_certificate_arn         = module.dns.certificate_arn
  enable_https                = var.enable_https
  app_namespace               = var.app_namespace
  api_gateway_service_name    = var.api_gateway_service_name
  api_gateway_service_port    = var.api_gateway_service_port
  lb_controller_chart_version = var.lb_controller_chart_version
  depends_on                  = [kubernetes_namespace.app]

}

module "dns" {
  source = "../../modules/dns"

  domain_name  = var.domain_name
  default_tags = var.default_tags
}

resource "aws_route53_record" "staging_a" {
  zone_id = module.dns.hosted_zone_id
  name    = "staging.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "staging_aaaa" {
  zone_id = module.dns.hosted_zone_id
  name    = "staging.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

module "rds" {
  source = "../../modules/rds"

  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  allowed_security_group_id = module.vpc.eks_node_sg_id
  db_name                   = var.db_name
  db_username               = var.mysql_username
  db_password               = var.mysql_password
  db_instance_class         = var.db_instance_class
  allocated_storage         = var.db_allocated_storage
  common_tags               = local.common_tags
}
