module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.1"

  cluster_name    = local.name
  cluster_version = "1.24"

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    configuration_values = jsonencode({
      env = {
        # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
        ENABLE_PREFIX_DELEGATION = true
        WARM_PREFIX_TARGET       = 1
      }
    })
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    initial = {
      instance_types = ["m5.large"]

      min_size     = 1
      max_size     = 1
      desired_size = 1

      # See issue https://github.com/awslabs/amazon-eks-ami/issues/844
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        set -ex

        cat <<-EOF > /etc/profile.d/bootstrap.sh
        export USE_MAX_PODS=false
        export KUBELET_EXTRA_ARGS="--max-pods=110"
        EOF
        # Source extra environment variables in bootstrap script
        sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
      EOT
    }
  }

  tags = module.tags.tags
}
