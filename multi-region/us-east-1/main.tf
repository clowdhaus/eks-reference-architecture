terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47"
    }
  }

  backend "s3" {
    bucket         = "clowd-haus-iac-us-east-1"
    key            = "eks-reference-architecture/multi-region/us-east-1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "clowd-haus-terraform-state"
    encrypt        = true
  }
}

provider "aws" {
  region = local.region

  # assume_role {
  #   role_arn     = "<TODO>"
  #   session_name = local.name
  # }
}

################################################################################
# Common Locals
################################################################################

locals {
  name        = "multi-region"
  region      = "us-east-1"
  environment = "nonprod"
}

################################################################################
# Common Data
################################################################################

# data "aws_availability_zones" "available" {}

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
