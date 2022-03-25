module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.7"

  cluster_name              = local.name
  cluster_version           = local.cluster_version
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Private network access only
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = false
  cluster_endpoint_public_access_cidrs = []

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks_secrets.arn
    resources        = ["secrets"]
  }]

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

    # Since we do not need any additional/separate access for the node group(s)
    # we can disable the creation of the placeholder security group
    create_security_group = false
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
            kms_key_id            = aws_kms_key.ebs.arn
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
  version = "~> 4.12"

  role_name_prefix      = "VPC-CNI-IRSA-"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = module.tags.tags
}

################################################################################
# EKS Secrets Custom KMS Key
################################################################################

resource "aws_kms_key" "eks_secrets" {
  description             = "EKS secrets encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.eks_secrets.json

  tags = module.tags.tags
}

data "aws_iam_policy_document" "eks_secrets" {
  statement {
    sid       = "RootUserAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }
}

################################################################################
# EBS Custom KMS Key
################################################################################

resource "aws_kms_key" "ebs" {
  description             = "EBS volume encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ebs.json

  tags = module.tags.tags
}

data "aws_iam_policy_document" "ebs" {
  statement {
    sid       = "RootUserAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid = "EncryptDecrypt"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:role/aws-service-role/autoscaling.${local.dns_suffix}/AWSServiceRoleForAutoScaling"]
    }
  }

  statement {
    sid = "Grant"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:role/aws-service-role/autoscaling.${local.dns_suffix}/AWSServiceRoleForAutoScaling"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}
