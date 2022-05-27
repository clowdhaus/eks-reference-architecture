# Serverless EKS Cluster using Fargate Profiles

## Features

If there are features that you think are missing, please feel free to open up a discussion via a GitHub issue. This is a great way to collaborate within the community and capture any shared knowledge for all to see; I will do my best to ensure that knowledge is captured somewhere within this project so that others can benefit from it.

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

### Tear Down & Clean-Up

1. Remove the resources created by Terraform

```bash
terraform destroy
```
