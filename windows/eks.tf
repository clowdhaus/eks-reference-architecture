module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.1"

  cluster_name    = local.name
  cluster_version = "1.24"

  cluster_endpoint_public_access = true

  # # EKS Addons
  # cluster_addons = {
  #   coredns    = {}
  #   kube-proxy = {}
  #   vpc-cni    = {}
  # }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    windows = {
      use_custom_launch_template = false

      ami_type = "WINDOWS_CORE_2022_x86_64"

      instance_types = ["m5.large"]

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  tags = module.tags.tags
}
