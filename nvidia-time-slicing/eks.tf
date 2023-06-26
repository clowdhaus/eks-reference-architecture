################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15"

  cluster_name    = local.name
  cluster_version = "1.25"

  cluster_endpoint_public_access = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    # hub-8081-ingress = {
    #   description = "Allow inbound traffic from hub on port 8081"
    #   type        = "ingress"
    #   from_port   = 8081
    #   to_port     = 8081
    #   protocol    = "tcp"
    #   cidr_blocks = [module.vpc.vpc_cidr_block]
    # }
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = {
    # This nodegroup is for core addons such as CoreDNS, as well as
    # any other addons/software that does not require GPU support
    non-gpu = {
      instance_types = ["m5.large"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    # This nodegroup is for GPU workloads
    gpu = {
      ami_type = "BOTTLEROCKET_x86_64_NVIDIA"
      platform = "bottlerocket"
      # create = false

      # ami_type = "AL2_x86_64_GPU"

      instance_types = ["g5.xlarge"]

      min_size     = 1
      max_size     = 1
      desired_size = 1

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 128
            volume_type = "gp3"
          }
        }
      }

      labels = {
        "nvidia.com/gpu.present" = "true"
      }

      taints = {
        # Ensure only GPU workloads are scheduled on this nodegroup
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  tags = module.tags.tags
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = module.tags.tags
}
