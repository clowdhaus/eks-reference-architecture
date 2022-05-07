locals {
  sso_path    = "/aws-reserved/sso.amazonaws.com/"
  plugin_name = "neuron-device-plugin"
}

data "aws_iam_roles" "sso_admin" {
  name_regex  = "AWSReservedSSO_AWSAdministratorAccess_.*"
  path_prefix = local.sso_path
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.20"

  cluster_name    = local.name
  cluster_version = "1.22"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      # Need to strip path -> https://github.com/kubernetes-sigs/aws-iam-authenticator/issues/268
      rolearn  = replace(one(data.aws_iam_roles.sso_admin.arns), "/${local.sso_path}/", "/")
      username = "sso_admin"
      groups   = ["system:masters"]
    },
  ]

  eks_managed_node_groups = {
    inf1 = {
      ami_type       = "AL2_x86_64_GPU"
      instance_types = ["inf1.xlarge"] # inf1.6xlarge
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 1
      desired_size = 1

      create_security_group = false
    }
  }

  tags = module.tags.tags
}

################################################################################
# AWS Neuron Device
################################################################################

resource "kubernetes_cluster_role_v1" "neuron_device" {
  metadata {
    name = local.plugin_name
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/status"]
    verbs      = ["update", "patch", ]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["update", "patch", "get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }
}

resource "kubernetes_service_account_v1" "neuron_device" {
  metadata {
    name      = local.plugin_name
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "neuron_device" {
  metadata {
    name = local.plugin_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.neuron_device.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.neuron_device.metadata[0].name
    namespace = kubernetes_service_account_v1.neuron_device.metadata[0].namespace
  }
}

resource "kubectl_manifest" "neuron_device_plugin_daemonset" {
  yaml_body = templatefile("templates/neuron-device-plugin.yaml", {
    # https://gallery.ecr.aws/neuron/neuron-device-plugin
    neuron_device_plugin_image = "public.ecr.aws/neuron/neuron-device-plugin:1.9.0.0"
  })
}
