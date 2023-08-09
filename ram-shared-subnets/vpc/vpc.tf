module "vpc" {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = module.tags.tags
}

################################################################################
# RAM resources
################################################################################

resource "aws_ram_resource_share" "this" {
  name = local.name
  tags = module.tags.tags
}

data "aws_organizations_organization" "this" {}

resource "aws_ram_principal_association" "this" {
  principal          = data.aws_organizations_organization.this.arn
  resource_share_arn = aws_ram_resource_share.this.arn
}

resource "aws_ram_resource_association" "this" {
  count = local.num_azs

  resource_arn       = element(module.vpc.private_subnet_arns, count.index)
  resource_share_arn = aws_ram_resource_share.this.arn
}
