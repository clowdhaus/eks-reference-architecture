# Weaviate vector DB on Amazon EKS

### Prerequisites:

Ensure that you have the following tools installed locally:

1. [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. [kubectl](https://Kubernetes.io/docs/tasks/tools/)
3. [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### Deployment

1. Provision resources as they are defined in the directory with the following. Note - ensure your CLI session is authenticated with AWS to provision resources.

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

3. With the cluster up and running we can check that Weaviate is functioning as intended. First, update your kubeconfig to access the cluster:

```bash
# First, make sure you have updated your local kubeconfig
aws eks --region us-west-2 update-kubeconfig --name weaviate
```

4. Ensure that the Weaviate resources are up and running:

```bash
kubectl get all -n weaviate

# Should return something similar to below
NAME                                         READY   STATUS    RESTARTS   AGE
pod/transformers-inference-8f6cf5c68-qbl6b   1/1     Running   0          127m
pod/weaviate-0                               1/1     Running   0          127m

NAME                             TYPE           CLUSTER-IP      EXTERNAL-IP                                                                     PORT(S)        AGE
service/transformers-inference   ClusterIP      172.20.174.46   <none>                                                                          8080/TCP       127m
service/weaviate                 LoadBalancer   172.20.208.27   k8s-weaviate-weaviate-81fdb6e0b6-99e5be031f5cd317.elb.us-west-2.amazonaws.com   80:30645/TCP   127m
service/weaviate-headless        ClusterIP      None            <none>                                                                          80/TCP         127m

NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/transformers-inference   1/1     1            1           127m

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/transformers-inference-8f6cf5c68   1         1         1       127m

NAME                        READY   AGE
statefulset.apps/weaviate   1/1     127m
```

5. Get the load balancer endpoint DNS name that will be used to connect to Weaviate. Save this for later, it will be used in the Sagemaker notebook to connect to the Weaviate cluster.

```bash
kubectl get svc -n weaviate weaviate -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

6. Open up Sagemaker in the AWS console - navigate to Studio and select the `weaviate` profile and click `Open Studio`
7. Once the Studio is launched, click `Create Notebook`
8. In the first cell of the notebook, install the Weaviate Python client:

```python
!python -m pip install -q pip --upgrade --root-user-action=ignore
!python -m pip install -q weaviate-client --root-user-action=ignore
```

9. In the second cell of the notebook, import the Weaviate client and create a client instance. Replace `<NLB_DNS_NAME>` with the NLB DNS name from step 5.

```python
import weaviate

client = weaviate.Client("http://<NLB_DNS_NAME>")
client.schema.get()
```

This should return the following after the cell is execute:
`{'classes': []}`

10. Populate the schema with some sample data:

```python
schema = {
  "classes": [{
    "class": "Publication",
    "description": "A publication with an online source",
    "properties": [
      {
        "dataType": [
          "text"
        ],
        "description": "Name of the publication",
        "name": "name"
      },
      {
        "dataType": [
          "Article"
        ],
        "description": "The articles this publication has",
        "name": "hasArticles"
      },
      {
        "dataType": [
            "geoCoordinates"
        ],
        "description": "Geo location of the HQ",
        "name": "headquartersGeoLocation"
      }
    ]
  }, {
    "class": "Article",
    "description": "A written text, for example a news article or blog post",
    "properties": [
      {
        "dataType": [
          "text"
        ],
        "description": "Title of the article",
        "name": "title"
      },
      {
        "dataType": [
          "text"
        ],
        "description": "The content of the article",
        "name": "content"
      }
    ]
  }, {
    "class": "Author",
    "description": "The writer of an article",
    "properties": [
      {
        "dataType": [
            "text"
        ],
        "description": "Name of the author",
        "name": "name"
      },
      {
        "dataType": [
            "Article"
        ],
        "description": "Articles this author wrote",
        "name": "wroteArticles"
      },
      {
        "dataType": [
            "Publication"
        ],
        "description": "The publication this author writes for",
        "name": "writesFor"
      }
    ]
  }]
}

client.schema.create(schema)
```

11. Now, when you execute `client.schema.get()`, the schema should return the populated data that was just added.

### Tear Down & Clean-Up

1. Remove the resources created by Terraform

```bash
terraform destroy -target=module.eks_blueprints_addons
terraform destroy
```
