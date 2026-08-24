output "role_arn" {
  description = "IAM role ARN — used to annotate the controller's Kubernetes ServiceAccount when installing via Helm"
  value       = aws_iam_role.controller.arn
}
