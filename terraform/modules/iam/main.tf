resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-iam-github-oidc"
  })
}

data "aws_iam_policy_document" "github_actions_ci_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_oidc.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_app_repo}:*",
        "repo:${var.github_org}/${var.github_infra_repo}:*"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions_ci" {
  name               = "spc-${var.environment}-ue1-iam-ro-github-ci"
  assume_role_policy = data.aws_iam_policy_document.github_actions_ci_assume_role.json

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-iam-ro-github-ci"
  })
}

resource "aws_iam_policy" "github_actions_ci_policy" {
  name        = "spc-${var.environment}-ue1-iam-policy-github-ci"
  description = "Least-privilege policy for GitHub Actions CI to build and push to ECR and read approved Secrets Manager secrets"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = concat(
      [
        {
          Sid      = "ECRAuthentication"
          Effect   = "Allow"
          Action   = ["ecr:GetAuthorizationToken"]
          Resource = ["*"]
        },
        {
          Sid    = "ECRPushPull"
          Effect = "Allow"
          Action = [
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:CompleteLayerUpload",
            "ecr:GetDownloadUrlForLayer",
            "ecr:InitiateLayerUpload",
            "ecr:PutImage",
            "ecr:UploadLayerPart",
            "ecr:DescribeRepositories",
            "ecr:ListImages"
          ]
          Resource = var.github_actions_ecr_repository_arns

        }
      ],
      length(var.github_actions_secret_arns) > 0 ? [
        {
          Sid    = "SecretsManagerRead"
          Effect = "Allow"
          Action = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue"
          ]
          Resource = var.github_actions_secret_arns
        }
      ] : []
    )
  })

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-iam-policy-github-ci"
  })
}


resource "aws_iam_role_policy_attachment" "github_actions_ci" {
  role       = aws_iam_role.github_actions_ci.name
  policy_arn = aws_iam_policy.github_actions_ci_policy.arn
}

resource "aws_iam_role" "terraform" {
  name               = "spc-${var.environment}-ue1-iam-ro-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_actions_ci_assume_role.json

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-iam-ro-terraform"
  })
}

resource "aws_iam_policy" "terraform_policy" {
  name        = "spc-${var.environment}-ue1-iam-policy-terraform"
  description = "Least-privilege policy for Terraform to provision AWS infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::spc-${var.environment}-ue1-tfstate",
          "arn:aws:s3:::spc-${var.environment}-ue1-tfstate/*"
        ]
      },
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = ["arn:aws:dynamodb:us-east-1:${var.aws_account_id}:table/spc-${var.environment}-ue1-tfstate-lock"]
      },
      {
        Sid    = "InfrastructureProvisioning"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "rds:*",
          "elasticloadbalancing:*",
          "iam:*",
          "s3:*",
          "ecr:*",
          "secretsmanager:*",
          "dynamodb:*",
          "route53:*",
          "acm:*",
          "autoscaling:*",
          "cloudwatch:*",
          "logs:*",
          "kms:*"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-iam-policy-terraform"
  })
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform_policy.arn
}

resource "aws_iam_role" "eks_node" {
  name = "spc-${var.environment}-ue1-iam-ro-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-iam-ro-eks-node"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role" "eks_cluster" {
  name = "spc-${var.environment}-ue1-iam-ro-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "spc-${var.environment}-ue1-iam-ro-eks-cluster"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
