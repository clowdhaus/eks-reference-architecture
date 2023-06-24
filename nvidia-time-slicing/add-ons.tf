################################################################################
# Addons
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Wait for compute to be available
  create_delay_dependencies = [for group in module.eks.eks_managed_node_groups : group.node_group_arn]

  enable_aws_load_balancer_controller = true
  # enable_aws_efs_csi_driver           = true

  enable_kube_prometheus_stack = true
  kube_prometheus_stack = {
    values = [
      <<-EOT
        prometheus:
          prometheusSpec:
            serviceMonitorSelectorNilUsesHelmValues: false
      EOT
    ]
  }

  enable_metrics_server = true

  helm_releases = {
    prometheus-adapter = {
      chart            = "prometheus-adapter"
      chart_version    = "4.2.0"
      repository       = "https://prometheus-community.github.io/helm-charts"
      description      = "A Helm chart for k8s prometheus adapter"
      namespace        = "prometheus-adapter"
      create_namespace = true
    }
    gpu-operator = {
      chart            = "gpu-operator"
      chart_version    = "v23.3.2"
      repository       = "https://nvidia.github.io/gpu-operator"
      description      = "A Helm chart for NVIDIA GPU operator"
      namespace        = "gpu-operator"
      create_namespace = true
      # Device plugin configuration enables time-slicing
      values = [
        <<-EOT
          driver:
            enabled: false
          operator:
            defaultRuntime: containerd
          devicePlugin:
            config:
              name: device-plugin
              create: true
              data:
                any: |-
                  version: v1
                  flags:
                    migStrategy: none
                  sharing:
                    timeSlicing:
                      resources:
                      - name: nvidia.com/gpu
                        replicas: 4
        EOT
      ]
    }
    juypterhub = {
      chart            = "jupyterhub"
      chart_version    = "2.0.0"
      repository       = "https://jupyterhub.github.io/helm-chart/"
      description      = "A Helm chart for Jupyter Hub"
      namespace        = "jupyterhub"
      create_namespace = true
      values = [
        <<-EOT
          proxy:
            service:
              annotations:
                alb.ingress.kubernetes.io/scheme: internet-facing
          singleuser:
            storage:
              dynamic:
                storageClass: gp3
            extraTolerations:
              - key: "nvidia.com/gpu"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
        EOT
      ]
    }
  }

  tags = module.tags.tags
}

################################################################################
# Storage Classes
################################################################################

resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  # The resources was already created by the ebs-csi-driver addon
  force = "true"

  metadata {
    name = "gp2"
  }

  annotations = {
    # Modify annotations to remove gp2 as default storage class
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      # Annotation to set gp3 as default storage class
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete" # For demo, otherwise use `Retain`
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    fsType = "ext4"
    type   = "gp3"
  }
}

# resource "kubernetes_storage_class_v1" "efs" {
#   metadata {
#     name = "efs"
#   }

#   storage_provisioner = "efs.csi.aws.com"
#   parameters = {
#     provisioningMode = "efs-ap" # Dynamic provisioning
#     fileSystemId     = module.efs.id
#     directoryPerms   = "700"
#   }

#   depends_on = [
#     module.eks_blueprints_addons
#   ]
# }

# module "efs" {
#   source  = "terraform-aws-modules/efs/aws"
#   version = "~> 1.1"

#   creation_token = local.name
#   name           = local.name

#   # Mount targets / security group
#   mount_targets = {
#     for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v }
#   }
#   security_group_description = "${local.name} EFS security group"
#   security_group_vpc_id      = module.vpc.vpc_id
#   security_group_rules = {
#     vpc = {
#       # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
#       description = "NFS ingress from VPC private subnets"
#       cidr_blocks = module.vpc.private_subnets_cidr_blocks
#     }
#   }

#   tags = module.tags.tags
# }
