terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }
}
provider "aws" { region = var.aws_region }
data "aws_availability_zones" "available" { state = "available" }
locals { azs = slice(data.aws_availability_zones.available.names, 0, 3); tags = { Project = var.cluster_name, ManagedBy = "Terraform", Series = "AWS-Production-Architecture" } }
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"; version = "~> 6.0"
  name = "${var.cluster_name}-vpc"; cidr = var.vpc_cidr; azs = local.azs
  private_subnets = ["10.30.0.0/20", "10.30.16.0/20", "10.30.32.0/20"]
  public_subnets = ["10.30.128.0/24", "10.30.129.0/24", "10.30.130.0/24"]
  enable_nat_gateway = true; one_nat_gateway_per_az = true; single_nat_gateway = false; enable_dns_hostnames = true
  public_subnet_tags = { "kubernetes.io/role/elb" = 1 }; private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }; tags = local.tags
}
module "eks" {
  source = "terraform-aws-modules/eks/aws"; version = "~> 21.0"
  name = var.cluster_name; kubernetes_version = var.kubernetes_version; vpc_id = module.vpc.vpc_id; subnet_ids = module.vpc.private_subnets
  endpoint_public_access = false; endpoint_private_access = true
  authentication_mode = "API"; enable_cluster_creator_admin_permissions = false
  access_entries = { platform_admin = { principal_arn = var.platform_admin_role_arn, policy_associations = { admin = { policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy", access_scope = { type = "cluster" } } } } }
  addons = { coredns = { most_recent = true }, kube-proxy = { most_recent = true }, vpc-cni = { most_recent = true }, eks-pod-identity-agent = { most_recent = true } }
  eks_managed_node_groups = { platform = { instance_types = ["m7i.large"], capacity_type = "ON_DEMAND", min_size = 3, desired_size = 3, max_size = 6, subnet_ids = module.vpc.private_subnets, labels = { workload = "platform" } } }
  enable_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  tags = local.tags
}
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
