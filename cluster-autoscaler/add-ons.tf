################################################################################
# Cluster Autoscaler - Pod Identity
################################################################################

module "cluster_autoscaler_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name                             = "cluster-autoscaler-${local.name}"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "cluster-autoscaler"
    }
  }

  tags = module.tags.tags
}

################################################################################
# Cluster Autoscaler - Helm Chart
################################################################################

resource "helm_release" "cluster_autoscaler" {
  namespace = "kube-system"
  name      = "cluster-autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.57.0"
  wait       = false

  values = [
    <<-EOT
    awsRegion: ${local.region}
    rbac:
      serviceAccount:
        name: cluster-autoscaler
    autoDiscovery:
      clusterName: ${module.eks.cluster_name}
    EOT
  ]
}
