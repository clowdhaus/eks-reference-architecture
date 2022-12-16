module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.29"

  cluster_name    = local.name
  cluster_version = "1.23"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    initial = {
      instance_types        = ["m5.large"]
      create_security_group = false

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  tags = module.tags.tags
}

################################################################################
# Kubectl Set Env Vars
################################################################################

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_id
}

locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = module.eks.cluster_id
      cluster = {
        certificate-authority-data = module.eks.cluster_certificate_authority_data
        server                     = module.eks.cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = module.eks.cluster_id
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.this.token
      }
    }]
  })
}

resource "null_resource" "set_env" {
  # By default this will only execute once. You can add to the `triggers` block to enforce when it should re-run
  # triggers = {}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    command = "kubectl set env daemonset/aws-node MINIMUM_IP_TARGET=0 WARM_IP_TARGET=2 -n kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)"
  }
}
