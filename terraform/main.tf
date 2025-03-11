provider "aws" {
  region = var.region
}

# Look for existing VPC with our tag
data "aws_vpcs" "existing" {
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

locals {
  vpc_exists = length(data.aws_vpcs.existing.ids) > 0
  vpc_id     = local.vpc_exists ? data.aws_vpcs.existing.ids[0] : module.vpc[0].vpc_id
}

# Get data about existing subnets if VPC exists
data "aws_subnets" "private" {
  count = local.vpc_exists ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  
  tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

data "aws_subnets" "public" {
  count = local.vpc_exists ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  
  tags = {
    "kubernetes.io/role/elb" = 1
  }
}

# Create VPC only if it doesn't exist
module "vpc" {
  count   = local.vpc_exists ? 0 : 1
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.19.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Use either existing or new subnets
locals {
  private_subnet_ids = local.vpc_exists ? data.aws_subnets.private[0].ids : module.vpc[0].private_subnets
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.34.0"
  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.micro"]
    }
  }

  cluster_endpoint_public_access = true

  tags = {
    Environment = "devnet"
    Project     = "limechain-geth"
  }
}

# Output the cluster endpoint for kubectl configuration
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}
