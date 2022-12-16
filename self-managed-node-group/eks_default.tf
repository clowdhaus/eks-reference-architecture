locals {
  cluster_version = "1.23"
}

module "eks_default" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.29"

  cluster_name    = "${local.name}-default"
  cluster_version = local.cluster_version

  # EKS Addons
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  # Encryption key
  create_kms_key = true
  cluster_encryption_config = [{
    resources = ["secrets"]
  }]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  self_managed_node_groups = {
    default = {
      # Is deprecated and will be removed in v19.x
      create_security_group = false

      instance_type = "m5.large"

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=lifecycle=${local.cluster_version}'"

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
  }

  tags = module.tags.tags
}
