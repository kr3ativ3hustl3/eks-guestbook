variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "oidc_provider_arn" {
  description = "This cluster's OIDC provider ARN (from the eks module)"
  type        = string
}

variable "oidc_provider_url" {
  description = "This cluster's OIDC provider URL, without the https:// prefix (from the eks module)"
  type        = string
}
