terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
  }

  backend "s3" {
    # Update the remote backend below to support your environment
    bucket         = "clowd-haus-iac-us-east-1"
    key            = "eks-reference-architecture/self-managed-node-group/us-east-1/terraform.tfstate"
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

provider "kubernetes" {
  host                   = module.eks_default.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_default.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_default.cluster_id]
  }
}

################################################################################
# Common Locals
################################################################################

locals {
  name        = "eks-ref-arch-self-mng"
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
