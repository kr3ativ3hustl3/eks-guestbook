variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag all resources in this project"
  type        = string
  default     = "eks-guestbook"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.2.0.0/24", "10.2.1.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for database subnets, one per AZ"
  type        = list(string)
  default     = ["10.2.20.0/24", "10.2.21.0/24"]
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "guestbook_admin"
}

variable "db_password" {
  description = "Master password for the RDS instance — set a real value in terraform.tfvars, never commit it"
  type        = string
  sensitive   = true
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version — check current supported versions before applying"
  type        = string
  default     = "1.31"
}

variable "github_repo" {
  description = "Your GitHub repo in owner/repo format, e.g. kr3ativ3hustl3/eks-guestbook"
  type        = string
}
