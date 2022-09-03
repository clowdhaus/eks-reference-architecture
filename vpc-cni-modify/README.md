# EKS Cluster w/ Modified VPC CNI Settings

Demonstrates a crude way of modifying the `aws-node` daemonset when provisioning EKS clusters.

## Steps to Provision

### Prerequisites

1. Terraform version 1.0 or later
2. awscli 2.x
3. kubectl 1.20 or later

### Deployment

```bash
terraform init -upgrade=true
terraform apply
```

### Tear Down & Clean-Up

```bash
terraform destroy
```
