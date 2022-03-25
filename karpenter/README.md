# EKS Cluster w/ Karpenter Autoscaling

## Features

If there are features that you think are missing, please feel free to open up a discussion via a GitHub issue. This is a great way to collaborate within the community and capture any shared knowledge for all to see; I will do my best to ensure that knowledge is captured somewhere within this project so that others can benefit from it.

- Minimalistic VPC and EKS cluster; this is focused on just what Karpenter requires to operate (i.e. - tags)
  - VPC is tagged for Karpenter autodiscovery of subnets that it should utilize for provisioning nodes
  - EKS cluster primary security group is tagged for Karpenter autodiscovery - this is the security group that it will use when provisioning nodes
- Karpenter Helm chart, provisioner, and example deployment
  - Note the provisioner includes an additional tag `{karpenter.sh/discovery: ${local.name} }` which is required for the Karpenter IRSA role permissions to function as intended (they are scoped to this tag)

## Steps to Provision

### Prerequisites

1. Terraform version 1.0 or later
2. awscli 2.x
3. kubectl 1.17 or later

### Deployment

1. Provision resources as they are defined in the `us-east-1` directory using:

```bash
terraform init -upgrade=true
terraform apply
```

2. Once the cluster is up and running and the node group is provisioned, update your Terraform state to align with changes made by the AWS API. This doesn't modify any resources, it just simply aligns your statefile with the current state. You can read more about this at the following links if interested:

- https://github.com/hashicorp/terraform/pull/28634
- https://github.com/hashicorp/terraform/issues/28803

```bash
terraform apply -refresh-only
terraform plan # should show `No changes. Your infrastructure matches the configuration.`
```

3. With the cluster up and running we can check that Karpenter is functioning as intended with the following command:

```bash
# First, make sure you have updated your local kubeconfig
aws eks --region us-east-1 update-kubeconfig --name eks-ref-arch-karpenter

# Second, scale the example deployment
kubectl scale deployment inflate --replicas 5

# You can watch Karpenter's controller logs with
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller
```

You should see a new node named `karpenter.sh/provisioner-name/default` eventually come up in the console; this was provisioned by Karpenter in response to the scaled deployment above.

### Tear Down & Clean-Up

Because Karpenter manages the state of node resources outside of Terraform, Karpenter created resources will need to be de-provisioned first before removing the remaining resources with Terraform.

1. Remove the example deployment created above and any nodes created by Karpenter

```bash
kubectl delete deployment inflate
kubectl delete node -l karpenter.sh/provisioner-name=default
```

2. Remove the resources created by Terraform

```bash
terraform destroy
```

3. Remove any remaining launch templates that were created by Karpenter

```bash
aws ec2 describe-launch-templates \
  | jq -r ".LaunchTemplates[].LaunchTemplateName" \
  | grep -i "Karpenter-eks-ref-arch-karpenter" \
```
