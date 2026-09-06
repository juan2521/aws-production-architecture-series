variable "aws_region" { type = string; default = "us-east-1" }
variable "cluster_name" { type = string; default = "production-eks" }
variable "vpc_cidr" { type = string; default = "10.30.0.0/16" }
variable "kubernetes_version" { type = string; description = "Set to an EKS-supported Kubernetes version validated for your deployment date." }
variable "platform_admin_role_arn" { type = string; description = "Federated IAM role used for controlled platform administration." }
