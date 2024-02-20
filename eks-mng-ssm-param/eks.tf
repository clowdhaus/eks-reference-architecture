locals {
  cluster_version = "1.29"
}

module "eks_al2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = local.cluster_version

  enable_cluster_creator_admin_permissions = true

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["t4g.large"]

      # Resolve AMI ID from SSM parameter
      ami_id = "resolve:ssm:/aws/service/eks/optimized-ami/${local.cluster_version}/amazon-linux-2/recommended/image_id"
      enable_bootstrap_user_data = true

      iam_role_additional_policies = {
        # Give the node permission to resolve the AMI ID from SSM
        ssm = aws_iam_policy.ssm.arn
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 64
            volume_type = "gp3"
          }
        }
      }

      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
  }

  tags = module.tags.tags
}

resource "aws_iam_policy" "ssm" {
  name_prefix        = "${local.name}-ssm"
  description = "Resolve AMI ID SSM parameter"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters*",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:${local.region}::parameter/aws/service/eks/*"
      },
    ]
  })

  tags = module.tags.tags
}
