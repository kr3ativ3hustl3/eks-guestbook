variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (from the networking module) — both the control plane and nodes live here, no NAT"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version — check current supported versions before applying, since old ones get deprecated (same lesson as the RDS engine version check)"
  type        = string
  default     = "1.31"
}
