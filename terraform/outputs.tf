output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (used by EKS nodes and the ALB, later phases)"
  value       = module.networking.public_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs (for RDS, later phases)"
  value       = module.networking.database_subnet_ids
}

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = module.database.db_endpoint
}

output "db_security_group_id" {
  description = "RDS security group ID — needed when wiring up EKS in Phase 4"
  value       = module.database.security_group_id
}

output "eks_cluster_name" {
  description = "EKS cluster name — use with 'aws eks update-kubeconfig'"
  value       = module.eks.cluster_name
}

output "eks_cluster_security_group_id" {
  description = "EKS-managed cluster security group ID — Phase 4 adds an ALB ingress rule here"
  value       = module.eks.cluster_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "EKS cluster's OIDC provider ARN — used in Phase 4 for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  description = "EKS cluster's OIDC provider URL — used in Phase 4 for IRSA"
  value       = module.eks.oidc_provider_url
}

output "ecr_repository_url" {
  description = "ECR repository URL — used by the k8s Deployment manifest and the build/push workflow"
  value       = module.ecr.repository_url
}

output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller — used to annotate its ServiceAccount when installing via Helm"
  value       = module.lb_controller_irsa.role_arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC — paste into the GitHub secret AWS_GITHUB_ACTIONS_ROLE_ARN"
  value       = module.github_cicd.role_arn
}
