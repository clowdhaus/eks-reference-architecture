module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = local.name
  cluster_version = "1.29"

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
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
# EBS Custom KMS Key
################################################################################

module "ebs_kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description = "EBS volume encryption key"

  # Policy
  key_administrators                = [data.aws_caller_identity.current.arn]
  key_service_roles_for_autoscaling = ["arn:${local.partition}:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]

  # Aliases
  aliases = ["${local.name}/ebs"]

  tags = module.tags.tags
}
