module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.14"

  cluster_name              = local.name
  cluster_version           = "1.26"
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnets
  enable_irsa = true

  eks_managed_node_group_defaults = {
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]

    # Note: We are using the IRSA created below for permissions.
    # However, we must deploy a new cluster with permissions for the VPC CNI
    # to provision IPs or else nodes will fail to join and node group creation fails.
    # This is ONLY required for creating a new cluster and can be disabled once the
    # cluster is up and running since the IRSA will be used at that point
    iam_role_attach_cni_policy = false
  }

  eks_managed_node_groups = {
    eks-reference-secure-1 = {
      ami_type = "BOTTLEROCKET_x86_64"
      platform = "bottlerocket"

      bootstrap_extra_args = <<-EOT
        # extra args added
        [settings.kernel]
        lockdown = "integrity"

        [settings.ntp]
        time-servers = ["169.254.169.123"]
      EOT

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 32
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = module.ebs_kms.key_arn
            delete_on_termination = true
          }
        }
      }
    }
  }

  tags = module.tags.tags
}

################################################################################
# VPC CNI IRSA
################################################################################

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix      = "VPC-CNI-IRSA-"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = module.tags.tags
}

################################################################################
# EBS Custom KMS Key
################################################################################

module "ebs_kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  description = "EBS volume encryption key"

  # Policy
  key_administrators                = [data.aws_caller_identity.current.arn]
  key_service_roles_for_autoscaling = ["arn:${local.partition}:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]

  # Aliases
  aliases = ["${local.name}/ebs"]

  tags = module.tags.tags
}
