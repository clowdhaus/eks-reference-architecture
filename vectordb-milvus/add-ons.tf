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

  helm_releases = {
    milvus = {
      chart            = "milvus"
      chart_version    = "4.0.29"
      repository       = "https://milvus-io.github.io/milvus-helm/"
      description      = "A Helm chart for Milvus vectordb"
      namespace        = "milvus"
      create_namespace = true
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
    module.eks.cluster_addons
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
    module.eks.cluster_addons
  ]
}
