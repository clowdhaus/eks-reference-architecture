module "eks_bottlerocket" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = "${local.name}-br"
  cluster_version = "1.29"

  # EKS Addons
  cluster_addons = {
    # aws-ebs-csi-driver = {}
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    bottlerocket = {
      ami_type = "BOTTLEROCKET_x86_64"
      platform = "bottlerocket"

      instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
  }

  tags = module.tags.tags
}
