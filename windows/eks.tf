module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = "1.29"

  endpoint_public_access = true

  # EKS Addons
  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    # Required for CoreDNS
    al2 = {
      instance_types = ["m6i.large", "m5.large"]

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
    windows = {
      use_custom_launch_template = false
      ami_type                   = "WINDOWS_CORE_2022_x86_64"
      platform                   = "windows"
      instance_types             = ["m5.large"]

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
  }

  tags = module.tags.tags
}
