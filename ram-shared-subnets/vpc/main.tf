terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Update the remote backend below to support your environment
    bucket         = "clowd-haus-iac-us-east-1"
    key            = "eks-reference-architecture/ram-shared-subnets/vpc/us-east-1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "clowd-haus-terraform-state"
    encrypt        = true
  }
}

provider "aws" {
  region = local.region

  assume_role {
    role_arn     = var.assume_role_arn
    session_name = local.name
  }
}

################################################################################
# Common Locals
################################################################################

locals {
  name        = "ram-shared-subnets"
  region      = "us-east-1"
  environment = "nonprod"

  num_azs  = 3
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, local.num_azs)
}

################################################################################
# Common Data
################################################################################

data "aws_availability_zones" "available" {}

################################################################################
# Common Modules
################################################################################

module "tags" {
  source  = "clowdhaus/tags/aws"
  version = "~> 1.0"

  application = local.name
  environment = local.environment
  repository  = "https://github.com/clowdhaus/eks-reference-architecture"
}
