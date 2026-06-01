################################################################################
# AWS Load Balancer Controller - Pod Identity
################################################################################

module "alb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name                            = "alb-controller-${local.name}"
  attach_aws_lb_controller_policy = true

  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = module.tags.tags
}

################################################################################
# AWS Load Balancer Controller - Helm Chart
################################################################################

resource "helm_release" "alb_controller" {
  namespace = "kube-system"
  name      = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.3.0"
  wait       = false

  values = [
    <<-EOT
    clusterName: ${module.eks.cluster_name}
    vpcId: ${module.vpc.vpc_id}
    EOT
  ]
}

################################################################################
# Metrics Server - Helm Chart
################################################################################

resource "helm_release" "metrics_server" {
  namespace = "kube-system"
  name      = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = "3.13.0"
  wait       = false
}

################################################################################
# Prometheus Adapter - Helm Chart
################################################################################

resource "helm_release" "prometheus_adapter" {
  namespace        = "prometheus-adapter"
  create_namespace = true
  name             = "prometheus-adapter"

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-adapter"
  version    = "5.3.0"
  wait       = false
}

################################################################################
# Weaviate - Helm Chart
################################################################################

resource "helm_release" "weaviate" {
  namespace        = "weaviate"
  create_namespace = true
  name             = "weaviate"

  repository = "https://weaviate.github.io/weaviate-helm"
  chart      = "weaviate"
  version    = "17.8.1"
  wait       = false

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
    module.eks,
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
    module.eks,
  ]
}
