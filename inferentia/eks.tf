locals {
  sso_path    = "/aws-reserved/sso.amazonaws.com/"
  plugin_name = "neuron-device-plugin"

  inferentia_instance_classes = ["inf1.xlarge", "inf1.2xlarge", "inf1.6xlarge", "inf1.4xlarge"]
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
  version = "~> 19.5"

  cluster_name    = local.name
  cluster_version = "1.24"

  cluster_endpoint_public_access = true

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
    }
  }

  tags = module.tags.tags
}

################################################################################
# AWS Neuron Device
################################################################################

# Hack to ensure cluster is ready to receive requests
resource "kubectl_server_version" "current" {}

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

  depends_on = [kubectl_server_version.current]
}

resource "kubernetes_service_account_v1" "neuron_device" {
  metadata {
    name      = local.plugin_name
    namespace = "kube-system"
  }

  depends_on = [kubectl_server_version.current]
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

resource "kubernetes_daemon_set_v1" "neuron_device" {
  metadata {
    name      = kubernetes_service_account_v1.neuron_device.metadata[0].name
    namespace = kubernetes_service_account_v1.neuron_device.metadata[0].namespace
  }

  spec {
    selector {
      match_labels = {
        name = "${local.plugin_name}-ds"
      }
    }

    strategy {
      type = "RollingUpdate"
    }

    template {
      metadata {
        labels = {
          name = "${local.plugin_name}-ds"
        }
        annotations = {
          "scheduler.alpha.kubernetes.io/critical-pod" = ""
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.neuron_device.metadata[0].name
        priority_class_name  = "system-node-critical"

        toleration {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }

        toleration {
          key      = "aws.amazon.com/neuron"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "beta.kubernetes.io/instance-type"
                  operator = "In"
                  values   = local.inferentia_instance_classes
                }

                match_expressions {
                  key      = "node.kubernetes.io/instance-type"
                  operator = "In"
                  values   = local.inferentia_instance_classes
                }
              }
            }
          }
        }

        container {
          # https://gallery.ecr.aws/neuron/neuron-device-plugin
          image             = "public.ecr.aws/neuron/neuron-device-plugin:2.12.5.0"
          name              = local.plugin_name
          image_pull_policy = "Always"

          env {
            name  = "KUBECONFIG"
            value = "/etc/kubernetes/kubelet.conf"
          }

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          security_context {
            allow_privilege_escalation = false

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "device-plugin"
            mount_path = "/var/lib/kubelet/device-plugins"
          }

          volume_mount {
            name       = "infa-map"
            mount_path = "/run"
          }
        }

        volume {
          name = "device-plugin"

          host_path {
            path = "/var/lib/kubelet/device-plugins"
          }
        }

        volume {
          name = "infa-map"

          host_path {
            path = "/run"
          }
        }
      }
    }
  }
}
