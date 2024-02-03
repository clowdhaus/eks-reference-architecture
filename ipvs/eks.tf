module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  # EKS Addons
  cluster_addons = {
    coredns = {}
    kube-proxy = {
      most_recent = true
      configuration_values = jsonencode({
        mode = "ipvs"
        ipvs = {
          scheduler = "lc"
        }
      })
    }
    vpc-cni = {}
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
        yum install -y ipvsadm

        ipvsadm -l
        modprobe ip_vs
        modprobe ip_vs_rr
        modprobe ip_vs_wrr
        modprobe ip_vs_sh
        modprobe ip_vs_lc
        modprobe nf_conntrack
      EOT
    }
  }

  tags = module.tags.tags
}
