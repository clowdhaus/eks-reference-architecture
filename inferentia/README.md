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

```sh
terraform init -upgrade
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
aws eks --region us-east-1 update-kubeconfig --name inferentia
```

4. Check that the AWS Neuron device daemonset is functioning as intended with the following command:

```sh
kubectl get ds neuron-device-plugin-daemonset --namespace kube-system
```

```text
NAME                             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
neuron-device-plugin-daemonset   1         1         1       1            1           <none>          9h
```

5. You can now require Inferentia devices in a k8s manifest as in the following example. The number of Inferentia devices can be adjusted using `aws.amazon.com/neurondevice`:

```yaml
resources:
  limits:
    aws.amazon.com/neurondevice: '1'
  requests:
    memory: 1024Mi
```


You can also request how many Neuron cores for even finer granularity of control with `aws.amazon.com/neuroncore`

```yaml
resources:
  limits:
    aws.amazon.com/neuroncore: '2'
  requests:
    memory: 1024Mi
```

You can see this with:

```sh
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,NeuronDevice:.status.allocatable.aws\.amazon\.com/neurondevice"
```

```text
NAME                          NeuronDevice
ip-10-0-27-51.ec2.internal    12
ip-10-0-29-251.ec2.internal   <none>
ip-10-0-38-72.ec2.internal    <none>
```

And:

```sh
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,NeuronCore:.status.allocatable.aws\.amazon\.com/neuroncore"
```

```text
NAME                          NeuronCore
ip-10-0-27-51.ec2.internal    24
ip-10-0-29-251.ec2.internal   <none>
ip-10-0-38-72.ec2.internal    <none>
```

6. To deploy the model pods and resources for inference requests, run the following command:

```sh
kubectl apply -f llama2.yaml
```

By default, the deployment is set to 0. You can scale up/down this deployment as needed with:

```sh
kubectl scale deployment llama2-ex -n llama2 --replicas 3
```

If you see the following pods in `UnexpectedAdmissionError`:

```text
NAMESPACE     NAME                                           READY   STATUS                     RESTARTS   AGE
...
llama2        llama2-ex-68d5c56f95-fpgg6                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-h9fvt                     0/1     UnexpectedAdmissionError   0          3m10s
llama2        llama2-ex-68d5c56f95-jtgz6                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-kx227                     1/1     Running                    0          3m8s
llama2        llama2-ex-68d5c56f95-kzps6                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-l4g6r                     1/1     Running                    0          2m38s
llama2        llama2-ex-68d5c56f95-nnxkb                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-pdm75                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-qqq4h                     0/1     UnexpectedAdmissionError   0          3m8s
llama2        llama2-ex-68d5c56f95-rkjpb                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-sw2d7                     0/1     UnexpectedAdmissionError   0          3m8s
llama2        llama2-ex-68d5c56f95-wnqgm                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-x86vw                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-x9dxd                     0/1     UnexpectedAdmissionError   0          3m9s
llama2        llama2-ex-68d5c56f95-zhdds                     0/1     UnexpectedAdmissionError   0          3m9s
```

You can clean these up with:

```sh
kubectl delete pods --field-selector status.phase=Failed -n llama2
```

7. Get the load balancer endpoint name with:

```sh
kubectl get -n llama2 ingress llama2-ex -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

This will show the endpoint that can be used to send requests to the model and get back results.

### Tear Down & Clean-Up

1. Remove the resources created by Terraform

```sh
# Necessary to avoid removing Terraform's permissions too soon before its finished
# cleaning up the resources it deployed inside the cluster
terraform state rm 'module.eks.aws_eks_access_entry.this["cluster_creator"]' || true
terraform state rm 'module.eks.aws_eks_access_policy_association.this["cluster_creator_admin"]' || true

terraform destroy -target='module.eks_blueprints_addons'
terraform destroy
```
