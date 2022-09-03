# Serverless EKS Cluster using Fargate Profiles - Primary Region `us-east-1`

This example shows how to provision a serverless cluster (serverless data plane) using Fargate Profiles.

There are some challenges to achieve this, primarily around the management and usage of CoreDNS on Fargate. There are alternative solutions shown on the internet, typically utilizing a `kubectl patch ...` command to update the compute type of the template spec annotation. This approach does work, but with the downside that the EKS service will eventually update the CoreDNS deployment and overwrite the patch, causing the CoreDNS deployment to fail due to insufficient capacity (it will be looking for EC2 compute when only Fargate is available).

The `preserve` setting was added to the addons API, allowing users to remove the addon from EKS API control and instead manage the addon themselves without disrupting the currently running software (preserves what currently exists, but now in the user's control, not the EKS API's control). However, this requires managing the addon first (as an EKS managed addon) and unfortunately this does not work for CoreDNS when using Fargate Profiles at this time. When trying to manage the CoreDNS addon, the addon deployment will fail due to the default compute type of EC2.

This example solution has been developed to work around these current limitations and provides:

- AWS EKS Cluster (control plane)
- AWS EKS Fargate Profiles for the `default` namespace and `kube-system` namespace. This covers the two core namespaces, including the namespace used by the `coredns`, `vpc-cni`, and `kube-proxy` addons, while additional profiles can be added as needed.
- AWS EKS managed addons `vpc-cni` and `kube-proxy`
- Self-managed CoreDNS addon deployed through a Helm chart. The default CoreDNS deployment provided by AWS EKS is removed and replaced with a self-managed CoreDNS deployment, while the `kube-dns` service is updated to allow Helm to assume control.

⚠️ The management of CoreDNS as demonstrated in this example is intended to be used on new clusters. Existing clusters with existing workloads will see downtime if the CoreDNS deployment is modified as shown here.

## Prerequisites:

Ensure that you have the following tools installed locally:

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

## Deploy

To provision this example:

```bash
terraform init
terraform apply
```

Enter `yes` at command prompt to apply


## Validate

The following command will update the `kubeconfig` on your local machine and allow you to interact with your EKS Cluster using `kubectl` to validate the CoreDNS deployment for Fargate.

1. Run `update-kubeconfig` command:

```bash
aws eks --region <REGION> update-kubeconfig --name <CLSUTER_NAME>
```

2. Test by listing all the pods running currently. The CoreDNS pod should reach a status of `Running` after approximately 60 seconds:

```bash
kubectl get pods -A

# Output should look like below
NAMESPACE     NAME                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-dcc8d4c97-2jvfb   1/1     Running   0          2m28s
```

⚠️ If the CoreDNS pod is stuck in `pending`, you may need to delete the pod and let the deployment provision a new one. There is the potential for a race condition with the deployment between the profile and the provisioner which could cause a pod to be stuck in pending when provisioning a new cluster for the first time.

## Destroy

To teardown and remove the resources created in this example:

```bash
terraform destroy
```

Enter `yes` at command prompt to destroy

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.5 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.10 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 4.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.5 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 18.29 |
| <a name="module_tags"></a> [tags](#module\_tags) | git@github.com:clowdhaus/terraform-tags.git | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 3.14 |

## Resources

| Name | Type |
|------|------|
| [helm_release.coredns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [null_resource.modify_kube_dns](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.remove_default_coredns_deployment](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_eks_addon_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
