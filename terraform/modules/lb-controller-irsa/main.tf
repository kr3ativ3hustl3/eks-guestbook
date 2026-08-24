##############################################################################
# LB CONTROLLER IRSA MODULE
#
# Creates: the IAM role the AWS Load Balancer Controller assumes via
# IRSA (IAM Roles for Service Accounts) — no static AWS credentials
# inside the cluster at all. The controller's Kubernetes
# ServiceAccount (created when it's installed via Helm in Phase 4's
# walkthrough) is annotated with this role's ARN, and EKS handles the
# rest via the OIDC provider set up in Phase 3.
#
# The IAM policy itself is AWS's own official, published policy for
# this controller — deliberately downloaded fresh by you rather than
# reproduced by hand here. It's a long, detailed policy (dozens of
# statements covering ALB/NLB/target-group/security-group management)
# that AWS updates from time to time; pulling it directly from AWS's
# own GitHub repo at apply time is more reliable than a hand-copied
# version drifting out of date. See the Phase 4 walkthrough for the
# exact download step — this file just references whatever's saved
# locally as iam-policy.json.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_iam_policy" "controller" {
  name   = "${var.project_name}-lb-controller-policy"
  policy = file("${path.module}/iam-policy.json")

  tags = {
    Project = var.project_name
  }
}

# Trust policy: only the specific Kubernetes ServiceAccount
# (kube-system/aws-load-balancer-controller) in THIS cluster may
# assume this role — not any pod, not any namespace.
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "controller" {
  name               = "${var.project_name}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}
