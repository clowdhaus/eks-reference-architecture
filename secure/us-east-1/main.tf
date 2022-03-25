terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "clowd-haus-iac-us-east-1"
    key            = "eks-reference-infrastructure/secure/us-east-1/terraform.tfstate"
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
  name        = "eks-reference-secure"
  region      = "us-east-1"
  environment = "prod"

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  dns_suffix = data.aws_partition.current.dns_suffix

  cluster_version = "1.21"
}

################################################################################
# Common Data
################################################################################

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

################################################################################
# Common Modules
################################################################################

module "tags" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git@github.com:clowdhaus/terraform-tags.git"

  environment = local.environment
  repository  = "https://github.com/clowdhaus/eks-reference-infrastructure"
}
