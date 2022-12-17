# EKS Cluster w/ IPVS

TODO

## Prerequisites:

Ensure that you have the following tools installed locally:

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

## Deploy

To provision this example:

```sh
terraform init
terraform apply
```

Enter `yes` at command prompt to apply


## Validate

The following command will update the `kubeconfig` on your local machine and allow you to interact with your EKS Cluster using `kubectl` to validate the deployment.

1. Run `update-kubeconfig` command:

```sh
aws eks --region us-east-1 update-kubeconfig --name ipv4-prefix-delegation
```

2. View the configmap of kube-proxy for IPVS settings:

```sh
kubectl -n kube-system get configmap kube-proxy-config -o yaml

# Output should look similar to below (truncated for brevity)
  iptables:
    masqueradeAll: false
    masqueradeBit: 14
    minSyncPeriod: 0s
    syncPeriod: 30s
  ipvs:
    excludeCIDRs: null
    minSyncPeriod: 0s
    scheduler: "lc"
    syncPeriod: 30s
  kind: KubeProxyConfiguration
  metricsBindAddress: 0.0.0.0:10249
  mode: "ipvs"
```

3. Inspect the logs of kube-proxy for IPVS setttings:

```sh
kubectl logs kube-proxy-nqcwp -n kube-system | grep ipvs

# Output should look similar to below (truncated for brevity)
I1217 22:12:56.578440       1 server_others.go:269] "Using ipvs Proxier"
I1217 22:12:56.578460       1 server_others.go:271] "Creating dualStackProxier for ipvs"
I1217 22:12:56.578818       1 proxier.go:506] "ipvs sync params" ipFamily=IPv4 minSyncPeriod="0s" syncPeriod="30s" burstSyncs=2
I1217 22:12:56.588651       1 proxier.go:1010] "Not syncing ipvs rules until Services and Endpoints have been received from master"
```

## Destroy

To teardown and remove the resources created in this example:

```sh
terraform destroy -auto-approve
```
