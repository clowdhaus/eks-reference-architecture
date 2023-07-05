resource "aws_sagemaker_domain" "this" {
  domain_name = local.name
  auth_mode   = "IAM"

  # To reach VPC private resources
  app_network_access_type       = "VpcOnly"
  app_security_group_management = "Customer"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  default_space_settings {
    execution_role = aws_iam_role.this.arn
    security_groups = [
      module.sagemaker_sg.security_group_id,
      module.vpc_endpoints_sg.security_group_id,
    ]
  }

  default_user_settings {
    execution_role = aws_iam_role.this.arn
    security_groups = [
      module.sagemaker_sg.security_group_id,
      module.vpc_endpoints_sg.security_group_id,
    ]
  }
}

resource "aws_iam_role" "this" {
  name                = local.name
  path                = "/"
  assume_role_policy  = data.aws_iam_policy_document.this.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"]
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_sagemaker_user_profile" "this" {
  domain_id         = aws_sagemaker_domain.this.id
  user_profile_name = local.name

  user_settings {
    execution_role = aws_iam_role.this.arn
    security_groups = [
      module.sagemaker_sg.security_group_id,
      module.vpc_endpoints_sg.security_group_id,
    ]
  }
}

module "sagemaker_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-sagemaker"
  description = "Security group for Sagemaker"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      description = "VPC CIDR HTTPS"
      cidr_blocks = join(",", module.vpc.private_subnets_cidr_blocks)
    },
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      description = "All egress"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = module.tags.tags
}
