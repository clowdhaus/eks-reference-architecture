################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  manage_default_security_group  = true
  default_security_group_tags    = { Name = "${local.name}-default" }
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                                 = true
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = 30
  flow_log_log_format                             = "$${interface-id} $${srcaddr} $${srcport} $${pkt-src-aws-service} $${dstaddr} $${dstport} $${pkt-dst-aws-service} $${protocol} $${flow-direction} $${traffic-path} $${action} $${log-status} $${subnet-id} $${az-id} $${sublocation-type} $${sublocation-id}"

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  manage_default_route_table = true
  default_route_table_tags   = { Name = "${local.name}-default" }

  manage_default_network_acl  = true
  default_network_acl_name    = local.name
  default_network_acl_tags    = { Name = "${local.name}-default" }
  default_network_acl_ingress = []
  default_network_acl_egress  = []

  public_dedicated_network_acl = true
  public_inbound_acl_rules = [
    {
      # All access from VPC CIDR
      "rule_number" : 100,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    },
    {
      # HTTPS IPv4
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 443,
      "to_port" : 443,
      "rule_action" : "allow"
    },
    {
      # HTTP IPv4
      "rule_number" : 120,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 80,
      "to_port" : 80,
      "rule_action" : "allow"
    },
    {
      # Ephemeral ports
      "rule_number" : 130,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
    },
  ]
  public_outbound_acl_rules = concat([for i, cidr_block in module.vpc.private_subnets_cidr_blocks :
    {
      # All access to private subnets
      "rule_number" : 100 + i,
      "cidr_block" : cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    }],
    [{
      # HTTPS IPv4
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 443,
      "to_port" : 443,
      "rule_action" : "allow"
      },
      {
        # HTTP IPv4
        "rule_number" : 120,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "tcp",
        "from_port" : 80,
        "to_port" : 80,
        "rule_action" : "allow"
      },
      {
        # NTP IPv4
        "rule_number" : 130,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "tcp",
        "from_port" : 123,
        "to_port" : 123,
        "rule_action" : "allow"
      },
      {
        # NTP IPv4
        "rule_number" : 131,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "udp",
        "from_port" : 123,
        "to_port" : 123,
        "rule_action" : "allow"
      },
      {
        # Ephemeral ports
        "rule_number" : 140,
        "cidr_block" : "0.0.0.0/0",
        "protocol" : "tcp",
        "from_port" : 1024,
        "to_port" : 65535,
        "rule_action" : "allow"
      },
  ])

  private_dedicated_network_acl = true
  private_inbound_acl_rules = [
    {
      # All access from VPC CIDR
      "rule_number" : 100,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    },
    {
      # Ephemeral ports
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
    }
  ]
  private_outbound_acl_rules = [
    {
      # All access to VPC CIDR
      "rule_number" : 100,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "allow"
    },
    {
      # HTTPS IPv4
      "rule_number" : 110,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 443,
      "to_port" : 443,
      "rule_action" : "allow"
    },
    {
      # HTTP IPv4
      "rule_number" : 120,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 80,
      "to_port" : 80,
      "rule_action" : "allow"
    },
    {
      # NTP TCP IPv4
      "rule_number" : 130,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 123,
      "to_port" : 123,
      "rule_action" : "allow"
    },
    {
      # NTP UDP IPv4
      "rule_number" : 131,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "udp",
      "from_port" : 123,
      "to_port" : 123,
      "rule_action" : "allow"
    },
    {
      # Return/response traffic ephemeral ports
      "rule_number" : 140,
      "cidr_block" : "0.0.0.0/0",
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
    },
  ]

  create_database_subnet_route_table = true
  database_dedicated_network_acl     = true
  database_inbound_acl_rules = concat([for i, cidr_block in module.vpc.public_subnets_cidr_blocks :
    {
      # Deny all access from public subnets
      "rule_number" : 100 + i,
      "cidr_block" : cidr_block
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "deny"
    }],
    [{
      # Allow all (remaining) PostgreSQL access from VPC CDIR
      "rule_number" : 110,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "tcp",
      "from_port" : 5432,
      "to_port" : 5432,
      "rule_action" : "allow"
      },
  ])
  database_outbound_acl_rules = concat([for i, cidr_block in module.vpc.public_subnets_cidr_blocks :
    {
      # Deny all access to public subnets
      "rule_number" : 100 + i,
      "cidr_block" : cidr_block,
      "protocol" : "-1",
      "from_port" : 0,
      "to_port" : 0,
      "rule_action" : "deny"
    }],
    [{
      # Allow all (remaining) ephemeral ports to VPC CIDR
      "rule_number" : 110,
      "cidr_block" : module.vpc.vpc_cidr_block,
      "protocol" : "tcp",
      "from_port" : 1024,
      "to_port" : 65535,
      "rule_action" : "allow"
      }
  ])

  tags = module.tags.tags
}

################################################################################
# VPC Endpoints
################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 4.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc_endpoints_sg.security_group_id]

  endpoints = merge({
    # ECR images are stored on S3
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags = {
        Name = "${local.name}-s3"
      }
    }
    },
    { for service in toset(["autoscaling", "ecr.api", "ecr.dkr", "ec2", "ec2messages", "sts", "logs", "ssm", "ssmmessages"]) :
      replace(service, ".", "_") =>
      {
        service             = service
        subnet_ids          = module.vpc.private_subnets
        private_dns_enabled = true
        tags                = { Name = "${local.name}-${service}" }
      }
  })

  tags = module.tags.tags
}

################################################################################
# VPC Endpoints - Security Group
################################################################################

module "vpc_endpoints_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-vpc-endpoints"
  description = "Security group for VPC endpoint access"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      description = "VPC CIDR HTTPS"
      cidr_blocks = join(",", module.vpc.private_subnets_cidr_blocks)
    },
  ]

  tags = module.tags.tags
}

################################################################################
# ACM Certificate
################################################################################

data "aws_acm_certificate" "this" {
  domain   = var.acm_certificate_domain
  statuses = ["ISSUED"]
}

################################################################################
# Client VPN
################################################################################

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = local.name
  client_cidr_block      = "172.16.0.0/20"
  split_tunnel           = true
  dns_servers            = [cidrhost(module.vpc.vpc_cidr_block, 2), "1.1.1.1", "1.0.0.1"]
  server_certificate_arn = data.aws_acm_certificate.this.arn
  session_timeout_hours  = 8

  vpc_id = module.vpc.vpc_id
  security_group_ids = [
    module.client_vpn_sg.security_group_id,
    module.eks.node_security_group_id, # allows access to API server for kubectl commands
  ]

  authentication_options {
    type              = "federated-authentication"
    saml_provider_arn = "arn:${local.partition}:iam::${local.account_id}:saml-provider/${local.name}-client-vpn"
  }

  connection_log_options {
    enabled              = true
    cloudwatch_log_group = aws_cloudwatch_log_group.client_vpn.id
  }

  tags = merge(module.tags.tags, {
    Name = "${local.name}-client-vpn"
  })
}

resource "aws_ec2_client_vpn_network_association" "this" {
  for_each = toset(module.vpc.private_subnets)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = each.value
}

resource "aws_ec2_client_vpn_authorization_rule" "this" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = module.vpc.vpc_cidr_block
  description            = "Full VPC access"
  authorize_all_groups   = true
}

resource "aws_cloudwatch_log_group" "client_vpn" {
  name              = "${local.name}-client-vpn"
  retention_in_days = 30

  tags = module.tags.tags
}

module "client_vpn_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "aws-client-vpn"
  description = "Security group for AWS Client VPN"
  vpc_id      = module.vpc.vpc_id

  egress_with_cidr_blocks = [
    {
      rule        = "postgresql-tcp"
      description = "Access PostgreSQL databases"
      cidr_blocks = join(",", module.vpc.database_subnets_cidr_blocks)
    },
    {
      rule        = "https-443-tcp"
      description = "Access HTTPS/443 for VPC endpoints"
      cidr_blocks = join(",", module.vpc.private_subnets_cidr_blocks)
    },
  ]

  tags = module.tags.tags
}
