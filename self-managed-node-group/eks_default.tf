module "eks_default" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.name}-default"
  cluster_version = "1.30"

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  self_managed_node_groups = {
    default = {
      instance_type = "m5.large"

      ami_type = "AL2023_x86_64_STANDARD"

      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
  }

  tags = module.tags.tags
}
