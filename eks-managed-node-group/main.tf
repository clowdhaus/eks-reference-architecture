terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Update the remote backend below to support your environment
    bucket         = "clowd-haus-iac-us-east-1"
    key            = "eks-reference-architecture/eks-managed-node-group/us-east-1/terraform.tfstate"
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
  name        = "eks-ref-arch-eks-mng"
  region      = "us-east-1"
  environment = "nonprod"

  # Used to determine correct partition (i.e. - `aws`, `aws-gov`, `aws-cn`, etc.)
  # partition = data.aws_partition.current.partition
}

################################################################################
# Common Data
################################################################################

# data "aws_partition" "current" {}

################################################################################
# Common Modules
################################################################################

module "tags" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git@github.com:clowdhaus/terraform-tags.git"

  application = local.name
  environment = local.environment
  repository  = "https://github.com/clowdhaus/eks-reference-architecture"
}
