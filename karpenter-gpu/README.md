# Karpenter GPU Autoscaling

### Prerequisites:

Ensure that you have the following tools installed locally:

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Deployment

1. Provision resources as they are defined in the directory with the following. Note - ensure your CLI session is authenticated with AWS to provision resources.

```bash
terraform init -upgrade=true
terraform apply -target=module.vpc -target=module.eks
terraform apply -target='module.eks_blueprints_addons.module.karpenter' -target=kubectl_manifest.karpenter_node_template
```

2. Once the cluster is up and running and the node group is provisioned, update your Terraform state to align with changes made by the AWS API. This doesn't modify any resources, it just simply aligns your statefile with the current state. You can read more about this at the following links if interested:

- https://github.com/hashicorp/terraform/pull/28634
- https://github.com/hashicorp/terraform/issues/28803

```bash
terraform apply -refresh-only
terraform plan # should show `No changes. Your infrastructure matches the configuration.`
```

3. With the cluster up and running we can check that Weaviate is functioning as intended. First, update your kubeconfig to access the cluster:

```bash
# First, make sure you have updated your local kubeconfig
aws eks --region us-west-2 update-kubeconfig --name karpenter-gpu
```

4. Deploy the sample GPU deployment:

```bash
kubectl apply -f gpu.yaml
```

5. Scale up the deployment and verify the pods deploy onto GPU (p or g-class) nodes:

```bash
kubectl scale deployment test-gpu --replicas=4

# Output should look similar to below
NAME                        READY   STATUS    RESTARTS   AGE
test-gpu-5964c55c7b-57zbd   1/1     Running   0          4m58s
test-gpu-5964c55c7b-gbw6r   1/1     Running   0          4m58s
test-gpu-5964c55c7b-lmkzh   1/1     Running   0          4m58s
test-gpu-5964c55c7b-qvfmp   1/1     Running   0          4m58s
```

### Tear Down & Clean-Up

1. Scale down the deployment so that the Karpenter created nodes are removed:

```bash
kubectl delete -f gpu.yaml
```

2. Remove the resources created by Terraform

```bash
terraform destroy -target=module.eks_blueprints_addons
terraform destroy
```
