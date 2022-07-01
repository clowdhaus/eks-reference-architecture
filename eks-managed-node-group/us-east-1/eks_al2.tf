module "eks_al2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.26"

  cluster_name    = "${local.name}-al2"
  cluster_version = "1.22"

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

  eks_managed_node_groups = {
    al2 = {
      instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
      capacity_type  = "SPOT"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 75
            volume_type = "gp3"
            iops        = 3000
            throughput  = 150
          }
        }
      }

      # Is deprecated and will be removed in v19.x
      create_security_group = false

      min_size     = 1
      max_size     = 3
      desired_size = 1

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }

  tags = module.tags.tags
}
