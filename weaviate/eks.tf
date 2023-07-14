################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15"

  cluster_name    = local.name
  cluster_version = "1.27"

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
    # Cross cluster communication for Weaviate services
    ingress_self_80 = {
      description = "Node to node tcp/80"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      self        = true
    }
    ingress_self_8080 = {
      description = "Node to node tcp/8080"
      protocol    = "tcp"
      from_port   = 8080
      to_port     = 8080
      type        = "ingress"
      self        = true
    }
  }

  eks_managed_node_groups = {
    # This nodegroup is for core addons such as CoreDNS,
    # as well as the Weaviate DB pod
    non-gpu = {
      instance_types = ["m6i.2xlarge"]

      min_size     = 1
      max_size     = 5
      desired_size = 2

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 128
            volume_type = "gp3"
          }
        }
      }
    }

    # This nodegroup is for GPU workloads such as the
    # Weaviate transformers
    gpu = {
      ami_type = "BOTTLEROCKET_x86_64_NVIDIA"
      platform = "bottlerocket"

      instance_types = ["g5.2xlarge"]

      min_size     = 1
      max_size     = 3
      desired_size = 2

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 128
            volume_type = "gp3"
          }
        }
        xvdb = {
          device_name = "/dev/xvdb"
          ebs = {
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
