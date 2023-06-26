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
  create_delay_dependencies = [for group in module.eks.eks_managed_node_groups : group.node_group_arn if group.node_group_arn != null]

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version = "1.5.4"
  }
  enable_aws_efs_csi_driver = true

  # enable_kube_prometheus_stack = false
  # kube_prometheus_stack = {
  #   values = [
  #     <<-EOT
  #       prometheus:
  #         prometheusSpec:
  #           serviceMonitorSelectorNilUsesHelmValues: false
  #     EOT
  #   ]
  # }

  # enable_metrics_server = false

  helm_releases = {
    # prometheus-adapter = {
    #   chart            = "prometheus-adapter"
    #   chart_version    = "4.2.0"
    #   repository       = "https://prometheus-community.github.io/helm-charts"
    #   description      = "A Helm chart for k8s prometheus adapter"
    #   namespace        = "prometheus-adapter"
    #   create_namespace = true
    # }
    juypterhub = {
      chart            = "jupyterhub"
      chart_version    = "2.0.0"
      repository       = "https://hub.jupyter.org/helm-chart/"
      description      = "A Helm chart for Jupyter Hub"
      namespace        = "jupyterhub"
      create_namespace = true
      values = [
        <<-EOT
          ingress:
            enabled: true
            annotations:
              alb.ingress.kubernetes.io/scheme: internet-facing
              alb.ingress.kubernetes.io/target-type: ip
              kubernetes.io/ingress.class: alb
          hub:
            db:
              pvc:
                storageClassName: gp3
          proxy:
            service:
              type: NodePort
          scheduling:
            userScheduler:
              nodeSelector:
                'nvidia.com/gpu.present': 'true'
              tolerations:
                - key: 'nvidia.com/gpu'
                  operator: 'Exists'
                  effect: 'NoSchedule'
          singleuser:
            image:
              name: jupyter/base-notebook
              tag: latest
            nodeSelector:
              'nvidia.com/gpu.present': 'true'
            storage:
              dynamic:
                storageClass: efs
                storageAccessModes: [ReadWriteMany]
            cmd:
              - jupyterhub-singleuser
            extraTolerations:
              - key: 'nvidia.com/gpu'
                operator: 'Exists'
                effect: 'NoSchedule'
            extraResource:
              limits:
                nvidia.com/gpu: 1
          prePuller:
            continuous:
              enabled: false
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

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode = "efs-ap" # Dynamic provisioning
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
  }

  mount_options = [
    "iam",
    "tls"
  ]

  depends_on = [
    module.eks_blueprints_addons
  ]
}

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.1"

  creation_token = local.name
  name           = local.name

  # Mount targets / security group
  mount_targets = {
    for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v }
  }
  security_group_description = "${local.name} EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    ingress_vpc_tcp = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
    ingress_vpc_udp = {
      # relying on the defaults provdied for EFS/NFS (2049/UDP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
      protocol    = "udp"
    }
  }

  tags = module.tags.tags
}
