##############################################################################
# EKS MODULE
#
# Creates: the EKS control plane, a managed node group (2x t3.small,
# public subnets, no NAT — same cost-saving pattern as project 3's
# Fargate tasks), the IAM roles both the cluster and nodes need, and
# an OIDC identity provider scoped to THIS cluster specifically — used
# in Phase 4 for IRSA (IAM Roles for Service Accounts), which lets the
# AWS Load Balancer Controller assume an IAM role without any static
# credentials.
#
# Note: this cluster-specific OIDC provider is unrelated to (and
# cannot collide with) the account-wide GitHub Actions OIDC provider
# used in projects 1-3 — EKS registers a new provider per cluster, at
# a cluster-specific issuer URL, not a fixed one like GitHub's.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

##############################################################################
# IAM roles
##############################################################################

resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

# Three managed policies covering exactly what a worker node needs:
# talk to the EKS control plane, manage pod networking (CNI), and
# pull images from ECR.
resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

##############################################################################
# EKS cluster + managed node group
##############################################################################

resource "aws_eks_cluster" "main" {
  #checkov:skip=CKV_AWS_39:Disabling the public endpoint entirely would break kubectl access from a local machine, which is exactly how this project's admin workflow operates throughout every phase - it would require standing up a VPN or bastion host inside the VPC just to run commands.
  #checkov:skip=CKV_AWS_38:Restricting the public endpoint to specific CIDRs is genuinely good practice in production, but would mean hardcoding a developer's current IP and updating it every time they're on a different network - impractical for a portfolio project picked up intermittently across different locations.
  #checkov:skip=CKV_AWS_58:Unlike SSM/SNS/ECR elsewhere in this series, EKS secrets envelope encryption has no free AWS-default-key option - it requires a real, billed Customer-Managed KMS Key (~$1/month), out of scope for a zero-new-cost security pass.
  #checkov:skip=CKV_AWS_37:Control plane logging is free to enable itself, but the logs stream to CloudWatch Logs with real per-GB ingestion/storage cost - especially audit logs, which record every API server request. Same reasoning as declining other new logging destinations throughout this series.
  name     = "${var.project_name}-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.public_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  # Modern EKS access management (API-based access entries) rather
  # than the older aws-auth ConfigMap approach — used in Phase 5 to
  # grant GitHub Actions kubectl access without editing an in-cluster
  # ConfigMap by hand.
  access_config {
    authentication_mode = "API"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]

  tags = {
    Project = var.project_name
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.public_subnet_ids
  instance_types  = ["t3.small"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  # AWS explicitly recommends this depends_on — without it, node
  # group creation can race the IAM policy attachments and fail.
  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]

  tags = {
    Project = var.project_name
  }
}

##############################################################################
# OIDC provider for IRSA (IAM Roles for Service Accounts) — lets
# Kubernetes service accounts assume IAM roles directly, used by the
# AWS Load Balancer Controller in Phase 4.
#
# Deliberately NOT using the `hashicorp/tls` provider's data source to
# compute this cluster's certificate thumbprint dynamically — that
# provider's compiled binary is another that requires a newer macOS
# than this project's development machine has (the same class of
# problem hit repeatedly across every project in this series).
# Instead, this uses a well-known, stable thumbprint value that's
# identical across all AWS EKS OIDC providers, since they're all
# backed by the same AWS certificate chain — a widely-documented value
# confirmed across multiple independent sources, not something
# specific to this one cluster.
##############################################################################

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Project = var.project_name
  }
}

##############################################################################
# Access entry — a genuinely surprising EKS detail: with
# `authentication_mode = "API"`, the IAM principal that CREATES the
# cluster is NOT automatically granted kubectl access, unlike the
# older ConfigMap-based auth mode where the creator was implicitly
# added as a cluster admin. Without this explicit grant, `kubectl`
# fails with "the server has asked for the client to provide
# credentials" even though `aws eks update-kubeconfig` succeeds and
# the AWS credentials themselves are perfectly valid.
##############################################################################

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
