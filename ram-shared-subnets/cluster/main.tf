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
    key            = "eks-reference-architecture/ram-shared-subnets/cluster/us-east-1/terraform.tfstate"
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
}

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
