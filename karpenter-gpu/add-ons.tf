################################################################################
# Addons
################################################################################

data "aws_ecrpublic_authorization_token" "this" {
  provider = aws.useast1
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Wait for compute to be available
  create_delay_dependencies = [for group in module.eks.eks_managed_node_groups :
    group.node_group_arn if group.node_group_arn != null
  ]

  enable_karpenter                  = true
  karpenter_enable_spot_termination = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.this.user_name
    repository_password = data.aws_ecrpublic_authorization_token.this.password
  }

  tags = module.tags.tags
}

################################################################################
# Default - Karpenter Provisioner
################################################################################

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      providerRef:
        name: default
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
      ttlSecondsAfterEmpty: 30
  YAML

  depends_on = [
    module.eks_blueprints_addons.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      amiFamily: Bottlerocket
      metadataOptions:
        httpEndpoint: enabled
        httpPutResponseHopLimit: 2
        httpTokens: required
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    kubectl_manifest.karpenter_provisioner
  ]
}

################################################################################
# GPU - Karpenter Provisioner
################################################################################

resource "kubectl_manifest" "karpenter_provisioner_gpu" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: gpu
    spec:
      providerRef:
        name: gpu
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: Gt
          values: ["6"]
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["g", "p"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: Gt
          values: ["2"]
      taints:
        - key: nvidia.com/gpu
          effect: "NoSchedule"
      ttlSecondsAfterEmpty: 30
  YAML

  depends_on = [
    module.eks_blueprints_addons.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template_gpu" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: gpu
    spec:
      amiFamily: Bottlerocket
      metadataOptions:
        httpEndpoint: enabled
        httpPutResponseHopLimit: 2
        httpTokens: required
      blockDeviceMappings:
        # Root device
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 10Gi
            volumeType: gp3
            encrypted: true
        # Data device: Container resources such as images and logs
        - deviceName: /dev/xvdb
          ebs:
            volumeSize: 64Gi
            volumeType: gp3
            encrypted: true
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    kubectl_manifest.karpenter_provisioner_gpu
  ]
}
