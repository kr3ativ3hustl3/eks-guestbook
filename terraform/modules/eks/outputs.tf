output "cluster_name" {
  description = "EKS cluster name — used by kubectl/aws eks update-kubeconfig"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate — needed for kubeconfig"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "The EKS-managed cluster security group — Phase 4 adds an ALB ingress rule here"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "This cluster's OIDC provider ARN — used in Phase 4 for the Load Balancer Controller's IRSA trust policy"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "This cluster's OIDC provider URL, without the https:// prefix — used in Phase 4's IRSA trust policy condition keys"
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "node_role_arn" {
  description = "IAM role ARN used by worker nodes"
  value       = aws_iam_role.node.arn
}
