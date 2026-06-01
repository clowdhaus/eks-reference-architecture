################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = "1.27"

  endpoint_public_access = true

  addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.arn
    }
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # NOTE: aws-auth configmap support removed in v21; an access_entry referencing
  # module.eks_blueprints_addons.karpenter.node_iam_role_arn creates a dependency
  # cycle with the addons module. Karpenter node access needs to be wired via
  # an externally-managed role or by migrating karpenter management out of
  # aws-ia/eks-blueprints-addons. Left for operator follow-up.

  eks_managed_node_groups = {
    default = {
      instance_types = ["m5.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
  }

  tags = merge(module.tags.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name = "${module.eks.cluster_name}-ebs-csi-driver-"

  use_name_prefix = true

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = module.tags.tags
}
