module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.14.0"

  cluster_name    = local.name
  cluster_version = "1.21"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Required for Karpenter role
  enable_irsa = true

  # For this example, we will only use the EKS created primary security group
  create_cluster_security_group = false
  create_node_security_group    = false

  # We only need one node to get Karpenter up and running. This ensures core
  # services such as VPC CNI, CoreDNS, etc. are up and running so that Karpetner
  # can be deployed and start managing any additional compute capacity requirements
  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]
      # For this example, we will only use the EKS created primary security group
      create_security_group                 = false
      attach_cluster_primary_security_group = true

      min_size     = 1
      max_size     = 1
      desired_size = 1

      iam_role_additional_policies = [
        # Required by Karpenter
        "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
    }
  }

  tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  }
}
