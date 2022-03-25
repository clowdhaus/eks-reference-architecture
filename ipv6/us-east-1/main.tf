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
    key            = "eks-reference-architecture/ipv6/us-east-1/terraform.tfstate"
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
  # name        = "ipv6"
  region      = "us-east-1"
  environment = "nonprod"
}

################################################################################
# Common Data
################################################################################

# tflint-ignore: terraform_unused_declarations
data "aws_caller_identity" "current" {}

################################################################################
# Common Modules
################################################################################

module "tags" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git@github.com:clowdhaus/terraform-tags.git"

  environment = local.environment
  repository  = "https://github.com/clowdhaus/eks-reference-architecture"
}
