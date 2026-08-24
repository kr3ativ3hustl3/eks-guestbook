variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "github_repo" {
  description = "Your GitHub repo in owner/repo format, e.g. kr3ativ3hustl3/eks-guestbook"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository this role is allowed to push to (from the ecr module)"
  type        = string
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster this role needs eks:DescribeCluster on, to run aws eks update-kubeconfig (from the eks module)"
  type        = string
}
