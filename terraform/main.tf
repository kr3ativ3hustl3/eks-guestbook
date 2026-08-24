##############################################################################
# ROOT MODULE — EKS Guestbook Project (project 4)
#
# Reuses the SAME S3 bucket + DynamoDB lock table as projects 1-3 —
# no new state backend setup needed. The `key` below keeps this
# project's state completely separate from the others.
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "sunificent-cloud-resume-tf-state-2026"
    key            = "eks-guestbook/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloud-resume-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  providers = { aws = aws }

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
}

module "database" {
  source = "./modules/database"

  providers = { aws = aws }

  project_name        = var.project_name
  vpc_id              = module.networking.vpc_id
  database_subnet_ids = module.networking.database_subnet_ids
  db_username         = var.db_username
  db_password         = var.db_password
}

module "eks" {
  source = "./modules/eks"

  providers = { aws = aws }

  project_name       = var.project_name
  public_subnet_ids  = module.networking.public_subnet_ids
  kubernetes_version = var.kubernetes_version
}

module "ecr" {
  source = "./modules/ecr"

  providers = { aws = aws }

  project_name = var.project_name
}

module "lb_controller_irsa" {
  source = "./modules/lb-controller-irsa"

  providers = { aws = aws }

  project_name      = var.project_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

module "github_cicd" {
  source = "./modules/github-cicd"

  providers = { aws = aws }

  project_name       = var.project_name
  github_repo        = var.github_repo
  ecr_repository_arn = module.ecr.repository_arn
}

# Grants GitHub Actions kubectl access to trigger rollouts — same
# category of problem as Phase 3's access entry for the deploying IAM
# user, but scoped much more narrowly here: edit access within the
# `default` namespace only, not cluster-admin. This role should never
# be able to touch kube-system, RBAC itself, or any other namespace.
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_cicd.role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_cicd.role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }
}

# Bridges the EKS node/cluster security group to RDS — same deferred
# pattern used in projects 2-3 (added now, once both sides exist).
# Not inside either module since it's a simple one-off connection
# between two independently-built resources.
resource "aws_security_group_rule" "rds_from_eks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.database.security_group_id
  source_security_group_id = module.eks.cluster_security_group_id
  description              = "Allow EKS nodes/pods to reach RDS"
}
