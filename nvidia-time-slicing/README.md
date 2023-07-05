# NVIDIA GPU Time-slicing on Amazon EKS

Get the endpoint:
```sh
k get ingress jupyterhub -n jupyterhub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Questions

1. What is the preferred storage type for the DB pod and transform pod - EBS or EFS?
2. The pod that hosts the DB does not require GPU; only the transform pod - correct?
3. Recommendations for authentication and how to handle multi-tenancy
4. Recommendations for development setup versus production

## Features

- TODO

## Steps to Provision

### Prerequisites:

Ensure that you have the following tools installed locally:

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

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
aws eks --region eu-west-1 update-kubeconfig --name nvidia-mig
```

4. TODO

### Tear Down & Clean-Up

1. Remove the resources created by Terraform

```bash
terraform destroy
```
