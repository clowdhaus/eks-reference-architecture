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

  enable_aws_efs_csi_driver           = true
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version = "1.5.4"
  }

  enable_metrics_server        = true
  enable_kube_prometheus_stack = false
  kube_prometheus_stack = {
    values = [
      <<-EOT
        prometheus:
          prometheusSpec:
            serviceMonitorSelectorNilUsesHelmValues: false
      EOT
    ]
  }

  helm_releases = {
    # juypterhub = {
    #   chart            = "jupyterhub"
    #   chart_version    = "2.0.0"
    #   repository       = "https://hub.jupyter.org/helm-chart/"
    #   description      = "A Helm chart for Jupyter Hub"
    #   namespace        = "jupyterhub"
    #   create_namespace = true
    #   values = [
    #     <<-EOT
    #       ingress:
    #         enabled: true
    #         annotations:
    #           alb.ingress.kubernetes.io/scheme: internal
    #           alb.ingress.kubernetes.io/target-type: ip
    #           kubernetes.io/ingress.class: alb
    #       hub:
    #         db:
    #           pvc:
    #             storageClassName: gp3
    #       proxy:
    #         service:
    #           type: NodePort
    #       scheduling:
    #         userScheduler:
    #           nodeSelector:
    #             'nvidia.com/gpu.present': 'true'
    #           tolerations:
    #             - key: 'nvidia.com/gpu'
    #               operator: 'Exists'
    #               effect: 'NoSchedule'
    #       singleuser:
    #         image:
    #           name: jupyter/base-notebook
    #           tag: latest
    #         nodeSelector:
    #           'nvidia.com/gpu.present': 'true'
    #         storage:
    #           dynamic:
    #             storageClass: efs
    #             storageAccessModes: [ReadWriteOnce]
    #         extraEnv:
    #           OPENAI_API_KEY: "${var.openai_api_key}"
    #           HUGGINGFACEHUB_API_TOKEN: "${var.huggingfacehub_api_token}"
    #         extraResource:
    #           limits:
    #             nvidia.com/gpu: 1
    #       prePuller:
    #         continuous:
    #           enabled: false
    #     EOT
    #   ]
    # }
    prometheus-adapter = {
      chart            = "prometheus-adapter"
      chart_version    = "4.2.0"
      repository       = "https://prometheus-community.github.io/helm-charts"
      description      = "A Helm chart for k8s prometheus adapter"
      namespace        = "prometheus-adapter"
      create_namespace = true
    }
    weaviate = {
      chart            = "weaviate"
      chart_version    = "16.3.1"
      repository       = "https://weaviate.github.io/weaviate-helm"
      description      = "A Helm chart for Weaviate"
      namespace        = "weaviate"
      create_namespace = true
      values = [
        <<-EOT
          service:
            type: NodePort
            annotations:
              alb.ingress.kubernetes.io/scheme: internal
              alb.ingress.kubernetes.io/target-type: ip
              kubernetes.io/ingress.class: alb

          storage:
            size: 32Gi
            storageClassName: efs

          default_vectorizer_module: text2vec-transformers

          modules:
            text2vec-transformers:
              enabled: true
              envconfig:
                # enable for CUDA support. Your K8s cluster needs to be configured
                # accordingly and you need to explicitly set GPU requests & limits below
                enable_cuda: true
              resources:
                requests:
                  # enable if running with CUDA support
                  nvidia.com/gpu: 1
                limits:
                  # enable if running with CUDA support
                  nvidia.com/gpu: 1
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
  # This is true because the resources was already created by the ebs-csi-driver addon
  force = "true"

  metadata {
    name = "gp2"
  }

  annotations = {
    # Modify annotations to remove gp2 as default storage class
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
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
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    encrypted = true
    fsType    = "ext4"
    type      = "gp3"
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
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
