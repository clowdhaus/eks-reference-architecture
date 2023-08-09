module "eks_al2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name    = local.name
  cluster_version = "1.27"

  cluster_endpoint_public_access = true

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = var.vpc_id
  subnet_ids = data.aws_subnets.private.ids

  eks_managed_node_groups = {
    default = {
      instance_types = ["m6i.large"]

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
  }

  tags = module.tags.tags
}

################################################################################
# RAM Shared Resource(s) Lookup
################################################################################

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

################################################################################
# Tag RAM Shared Resource(s)
################################################################################

locals {
  # Psuedo re-create tags for shared VPC
  vpc_tags = merge(
    { Name = local.name },
    module.tags.tags,
  )

  # Psuedo re-create tags for shared subnets
  subnet_tags = merge(
    { "kubernetes.io/role/internal-elb" = 1 },
    local.vpc_tags,
  )
}

# VPC tags, and tags for the resources within the shared VPC are not shared with the participants
# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-sharing.html#vpc-share-limitations
resource "aws_ec2_tag" "vpc" {
  for_each = local.vpc_tags

  resource_id = var.vpc_id
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "subnet_a" {
  for_each = local.subnet_tags

  resource_id = element(data.aws_subnets.private.ids, 0)
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "subnet_b" {
  for_each = local.subnet_tags

  resource_id = element(data.aws_subnets.private.ids, 1)
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "subnet_c" {
  for_each = local.subnet_tags

  resource_id = element(data.aws_subnets.private.ids, 2)
  key         = each.key
  value       = each.value
}
