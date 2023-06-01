################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.14"

  cluster_name    = local.name
  cluster_version = "1.27"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    # This nodegroup is for core addons such as CoreDNS,
    # as well as any other addons/software that does not
    # require GPU support
    non-gpu = {
      instance_types = ["m5.large"]

      min_size     = 1
      max_size     = 5
      desired_size = 2
    }
    # This nodegroup is strictly for GPU workloads
    gpus = {
      # We want the daemonset deployed before the nodegroup
      # to ensure the GPU operator is ready to configure GPU
      # backed nodes as they launch
      # create = false

      instance_types = ["p4d.24xlarge"]

      min_size     = 1
      max_size     = 1
      desired_size = 1

      taints = {
        dedicated = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  tags = module.tags.tags
}
