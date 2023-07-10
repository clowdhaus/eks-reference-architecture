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
      chart_version    = "16.4.0"
      repository       = "https://weaviate.github.io/weaviate-helm"
      description      = "A Helm chart for Weaviate"
      namespace        = "weaviate"
      create_namespace = true
      values = [
        <<-EOT
          image:
            tag: 1.20.0

          service:
            type: LoadBalancer
            annotations:
              service.beta.kubernetes.io/aws-load-balancer-internal: "true"
              service.beta.kubernetes.io/aws-load-balancer-type: nlb-ip
              service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"

          storage:
            size: 64Gi
            storageClassName: gp3

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
