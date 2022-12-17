locals {
  cluster_version = "1.24"
}

module "eks_default" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.1"

  cluster_name    = "${local.name}-default"
  cluster_version = local.cluster_version

  cluster_endpoint_public_access = true

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  self_managed_node_groups = {
    default = {
      instance_type = "m5.large"

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=lifecycle=${local.cluster_version}'"

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
  }

  tags = module.tags.tags
}
