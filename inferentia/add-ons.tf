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
# AWS Neuron Device Plugin
################################################################################

locals {
  neuron_device_plugin_version = "v2.17.0"
}

data "http" "neuron_device_plugin" {
  url = "https://raw.githubusercontent.com/aws-neuron/aws-neuron-sdk/${local.neuron_device_plugin_version}/src/k8/k8s-neuron-device-plugin.yml"
}

data "kubectl_file_documents" "neuron_device_plugin" {
  content = data.http.neuron_device_plugin.response_body
}

resource "kubectl_manifest" "neuron_device_plugin" {
  for_each = data.kubectl_file_documents.neuron_device_plugin.manifests

  yaml_body = each.value
}

# Cluster Role
data "http" "neuron_device_plugin_clusterrole" {
  url = "https://raw.githubusercontent.com/aws-neuron/aws-neuron-sdk/${local.neuron_device_plugin_version}/src/k8/k8s-neuron-device-plugin-rbac.yml"
}

data "kubectl_file_documents" "neuron_device_plugin_clusterrole" {
  content = data.http.neuron_device_plugin_clusterrole.response_body
}

resource "kubectl_manifest" "neuron_device_plugin_clusterrole" {
  for_each = data.kubectl_file_documents.neuron_device_plugin_clusterrole.manifests

  yaml_body = each.value
}

################################################################################
# AWS Neuron Scheduler
################################################################################

data "http" "neuron_scheduler" {
  url = "https://raw.githubusercontent.com/aws-neuron/aws-neuron-sdk/${local.neuron_device_plugin_version}/src/k8/k8s-neuron-scheduler-eks.yml"
}

data "kubectl_file_documents" "neuron_scheduler" {
  content = data.http.neuron_scheduler.response_body
}

resource "kubectl_manifest" "neuron_scheduler" {
  for_each = { for k, v in data.kubectl_file_documents.neuron_scheduler.manifests : k => v if k != "/apis/apps/v1/namespaces/kube-system/deployments/k8s-neuron-scheduler" }

  yaml_body = each.value
}

# Patching the deployment to run on the Inferentia nodes
resource "kubectl_manifest" "neuron_scheduler_patch" {
  yaml_body = <<-EOT
    # deployment yaml
    ---
    kind: Deployment
    apiVersion: apps/v1
    metadata:
      name: k8s-neuron-scheduler
      namespace: kube-system
    spec:
      replicas: 1
      strategy:
        type: Recreate
      selector:
        matchLabels:
            app: neuron-scheduler
            component: k8s-neuron-scheduler
      template:
        metadata:
          labels:
            app: neuron-scheduler
            component: k8s-neuron-scheduler
        spec:
          hostNetwork: true
          tolerations:
          - effect: NoSchedule
            operator: Exists
            key: aws.amazon.com/neuron
          serviceAccount: k8s-neuron-scheduler
          containers:
            - name: neuron-scheduler
              image: public.ecr.aws/neuron/neuron-scheduler:2.19.16.0
              env:
              - name: PORT
                value: "12345"
  EOT

  depends_on = [
    kubectl_manifest.neuron_scheduler,
  ]
}
