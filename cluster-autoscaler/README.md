# EKS Cluster w/ Cluster Autoscaler

### Prerequisites:

Ensure that you have the following tools installed locally:

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Deployment

1. Provision resources as they are defined in the `us-east-1` directory using:

```sh
terraform init -upgrade=true
terraform apply
```

2. Once the cluster is up and running and the node group is provisioned, update your Terraform state to align with changes made by the AWS API. This doesn't modify any resources, it just simply aligns your statefile with the current state. You can read more about this at the following links if interested:

- https://github.com/hashicorp/terraform/pull/28634
- https://github.com/hashicorp/terraform/issues/28803

```sh
terraform apply -refresh-only
terraform plan # should show `No changes. Your infrastructure matches the configuration.`
```

3. Update your kubeconfig to access the cluster:

```sh
aws eks --region us-east-1 update-kubeconfig --name cluster-autoscaler
```

4. Deploy the sample inflate deployment - this will cause cluster-autoscaler to scale up the nodegroup to satisfy the pending pod requests:

```sh
kubectl apply -f inflate.yaml
```

### Tear Down & Clean-Up

1. Remove the resources created by Terraform

```sh
terraform destroy -target=module.eks_blueprints_addons
terraform destroy
```
