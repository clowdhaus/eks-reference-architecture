# EKS Cluster w/ AWS Neuron on AWS Inferentia Instances

## Features

See more details [here](https://awsdocs-neuron.readthedocs-hosted.com/en/v1.19.0/neuron-deploy/tutorials/tutorial-k8s.html#tutorial-k8s-env-setup-for-neuron)

[EKS Machine learning inference using AWS Inferentia](https://docs.aws.amazon.com/eks/latest/userguide/inferentia-support.html)

## Steps to Provision

### Prerequisites

1. Terraform version 1.0 or later
2. awscli 2.x
3. kubectl 1.20 or later

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

4. [Optional] The [Deploy a TensorFlow Resnet50 model as a Kubernetes service](https://awsdocs-neuron.readthedocs-hosted.com/en/v1.19.0/neuron-deploy/v1/tutorials/k8s_rn50_demo.html#example-deploy-rn50-as-k8s-service) tutorial provides an example how to use k8s with Inferentia.

### Tear Down & Clean-Up

1. Remove the resources created by Terraform

```bash
terraform destroy
```
