# EKS Cluster w/ AWS Neuron on AWS Inferentia Instances

## Features

See more details [here](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/containers/index.html?tutorials%2Ftutorial-k8s.html=)

[EKS Machine learning inference using AWS Inferentia](https://docs.aws.amazon.com/eks/latest/userguide/inferentia-support.html)

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

2. With the cluster up and running we can check that the AWS Neuron device daemonset is functioning as intended with the following command:

```bash
kubectl get ds neuron-device-plugin-daemonset --namespace kube-system
```

3. You can now require Inferentia devices in a k8s manifest as in the following example. The number of Inferentia devices can be adjusted using the aws.amazon.com/neuron resource:

```yaml
resources:
  limits:
    aws.amazon.com/neuron: 1
  requests:
    memory: 1024Mi
```

### Tear Down & Clean-Up

1. Remove the resources created by Terraform

```bash
terraform destroy
```
