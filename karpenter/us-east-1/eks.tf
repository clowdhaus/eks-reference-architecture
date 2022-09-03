module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.29"

  cluster_name    = local.name
  cluster_version = "1.23"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Required for Karpenter role
  enable_irsa = true

  node_security_group_additional_rules = {
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Node group for Karpenter webhook"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Node group for ALB controller webhook"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

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

      iam_role_additional_policies = [
        # Required by Karpenter
        "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
    }
  }

  tags = merge(module.tags.tags, {
    # This will tag the launch template created for use by Karpenter
    "karpenter.sh/discovery/${local.name}" = local.name
  })
}
