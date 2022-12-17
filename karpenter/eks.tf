module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.1"

  cluster_name    = local.name
  cluster_version = "1.24"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Required for Karpenter role
  enable_irsa = true

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery/${local.name}" = local.name
  }

  # We only need one node to get Karpenter up and running. This ensures core
  # services such as VPC CNI, CoreDNS, etc. are up and running so that Karpetner
  # can be deployed and start managing any additional compute capacity requirements
  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]
      # Not required nor used - avoid tagging two security groups with same tag as well
      create_security_group = false

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  tags = merge(module.tags.tags, {
    # This will tag the launch template created for use by Karpenter
    "karpenter.sh/discovery/${local.name}" = local.name
  })
}
