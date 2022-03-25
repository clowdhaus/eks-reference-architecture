# Private EKS Cluster

## Features

If there are features that you think are missing, please feel free to open up a discussion via a GitHub issue. This is a great way to collaborate within the community and capture any shared knowledge for all to see; I will do my best to ensure that knowledge is captured somewhere within this project so that others can benefit from it.

- Cluster public endpoint access disabled; only private endpoint access enabled
- Cluster secrets encrypted with customer managed KMS key
- EBS volumes encrypted with customer managed KMS key
- EC2 instances (nodes) use BottleRocket OS
- AWS service access via VPC endpoints and or Gateway endpoints
- VPC default NACLs modified to deny all traffic; custom NACLs provided
- VPC default security group modified to deny all traffic

## Steps to Provision

### Prerequisites

1. You must have AWS SSO enabled on your account/organization. We will be using AWS Client VPN to provide user access to the cluster and AWS SSO is used to authenticate users when accessing the client VPN.
  - Refer to https://medium.com/trackit/how-to-create-an-aws-client-vpn-endpoint-using-aws-sso-and-terraform-6902dff5b71b up to `Step 3: Terraform Configuration` (ignore this section since we will be handling our own Terraform configuration here).
2. Download and install AWS Client VPN client https://aws.amazon.com/vpn/client-vpn-download/
2. You must have a valid AWS ACM certificate. This is required to setup the AWS Client VPN to ensure traffic across the VPN client is TLS encrypted

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

<!-- TODO - remove in favor of Cilium's CNI -->
3. With the cluster up and running we can start making some adjustments. First, lets remove the VPC CNI permissions from the nodes and instead rely on the IRSA created specifically for the VPC CNI addon. In the `eks.tf` file, change `iam_role_attach_cni_policy` from `true` to `false`:

```hcl
  # Change this line from `true` to `false`
  iam_role_attach_cni_policy = true -> false
```

After saving your changes, run the following commands to update your resources:

```bash
terraform apply
terraform apply -refresh-only # re-sync our state to match the change we performed
```

4. AWS Client VPN setup -> https://aws.amazon.com/blogs/security/authenticate-aws-client-vpn-users-with-aws-single-sign-on/
- https://medium.com/trackit/how-to-create-an-aws-client-vpn-endpoint-using-aws-sso-and-terraform-6902dff5b71b
