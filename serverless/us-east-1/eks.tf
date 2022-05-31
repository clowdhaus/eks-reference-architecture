module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.21"

  cluster_name    = local.name
  cluster_version = "1.22"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    kube-proxy = {
      addon_version     = data.aws_eks_addon_version.this["kube-proxy"].version
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      addon_version     = data.aws_eks_addon_version.this["vpc-cni"].version
      resolve_conflicts = "OVERWRITE"
    }
  }

  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        { namespace = "default" }
      ]
    }

    kube_system = {
      name = "kube-system"
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }

  tags = module.tags.tags
}

data "aws_eks_addon_version" "this" {
  for_each = toset(["coredns", "kube-proxy", "vpc-cni"])

  addon_name         = each.value
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

################################################################################
# Modify EKS CoreDNS Deployment
################################################################################

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_id
}

locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = module.eks.cluster_id
      cluster = {
        certificate-authority-data = module.eks.cluster_certificate_authority_data
        server                     = module.eks.cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = module.eks.cluster_id
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.this.token
      }
    }]
  })
}

# Separate resource so that this is only ever executed once
resource "null_resource" "remove_default_coredns_deployment" {
  triggers = {}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    # We are removing the deployment provided by the EKS service and replacing it through the self-managed CoreDNS Helm addon
    # However, we are maintaing the existing kube-dns service and annotating it for Helm to assume control
    command = <<-EOT
      kubectl --namespace kube-system delete deployment coredns --kubeconfig <(echo $KUBECONFIG | base64 --decode)
    EOT
  }
}

resource "null_resource" "modify_kube_dns" {
  triggers = {}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    # We are maintaing the existing kube-dns service and annotating it for Helm to assume control
    command = <<-EOT
      echo "Setting implicit dependency on ${module.eks.fargate_profiles["kube_system"].fargate_profile_pod_execution_role_arn}"
      kubectl --namespace kube-system annotate --overwrite service kube-dns meta.helm.sh/release-name=coredns --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      kubectl --namespace kube-system annotate --overwrite service kube-dns meta.helm.sh/release-namespace=kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      kubectl --namespace kube-system label --overwrite service kube-dns app.kubernetes.io/managed-by=Helm --kubeconfig <(echo $KUBECONFIG | base64 --decode)
    EOT
  }

  depends_on = [
    null_resource.remove_default_coredns_deployment
  ]
}

################################################################################
# CoreDNS Helm Chart (self-managed)
################################################################################

resource "helm_release" "coredns" {
  name             = "coredns"
  namespace        = "kube-system"
  create_namespace = false
  description      = "CoreDNS is a DNS server that chains plugins and provides Kubernetes DNS Services"
  chart            = "coredns"
  version          = "1.19.4"
  repository       = "https://coredns.github.io/helm"
  force_update     = true
  recreate_pods    = true

  # For EKS image repositories https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
  values = [
    <<-EOT
      image:
        repository: 602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/coredns
        tag: ${data.aws_eks_addon_version.this["coredns"].version}
      deployment:
        name: coredns
        annotations:
          eks.amazonaws.com/compute-type: fargate
      service:
        name: kube-dns
        annotations:
          eks.amazonaws.com/compute-type: fargate
      podAnnotations:
        eks.amazonaws.com/compute-type: fargate
      EOT
  ]
}
