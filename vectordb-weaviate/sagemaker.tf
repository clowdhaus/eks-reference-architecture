resource "aws_sagemaker_notebook_instance" "this" {
  name     = local.name
  role_arn = aws_iam_role.this.arn

  instance_type       = "ml.t2.medium"
  platform_identifier = "notebook-al2-v2"
  volume_size         = 128

  subnet_id       = element(module.vpc.private_subnets, 0)
  security_groups = [module.sagemaker_sg.security_group_id]

  instance_metadata_service_configuration {
    minimum_instance_metadata_service_version = 2
  }

  lifecycle_config_name = aws_sagemaker_notebook_instance_lifecycle_configuration.this.name

  tags = module.tags.tags
}

resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "this" {
  name = local.name

  # on_create = base64encode(
  #   <<-EOT
  #     #!/bin/bash

  #     set -e

  #     # OVERVIEW
  #     # This script installs a single conda package in all SageMaker conda environments, apart from the JupyterSystemEnv
  #     # which is a system environment reserved for Jupyter.

  #     # NOTE: if the total runtime of this script exceeds 5 minutes, the Notebook Instance will fail to start up.  If you
  #     # would like to run this script in the background, then replace "sudo" with "nohup sudo -b".  This will allow the
  #     # Notebook Instance to start up while the installation happens in the background.

  #     sudo -u ec2-user -i <<'EOF'

  #     # PARAMETERS
  #     PACKAGE=weaviate-client

  #     # Note that "base" is special environment name, include it there as well.
  #     conda install "$PACKAGE" --name base --yes

  #     for env in /home/ec2-user/anaconda3/envs/*; do
  #         env_name=$(basename "$env")
  #         if [ $env_name = 'JupyterSystemEnv' ]; then
  #             continue
  #         fi

  #         conda install "$PACKAGE" --name "$env_name" --yes
  #     done

  #     EOF
  #   EOT
  # )
  on_start = base64encode(
    <<-EOT
      #!/bin/bash

      set -e

      # Set environment variables for notebooks
      touch /etc/profile.d/jupyter-env.sh
      echo "export WEAVIATE_S3_BUCKET=${module.s3_bucket.s3_bucket_id}" >> /etc/profile.d/jupyter-env.sh

      # Restart command is dependent on current running Amazon Linux and JupyterLab
      CURR_VERSION=$(cat /etc/os-release)
      if [[ $CURR_VERSION == *$"http://aws.amazon.com/amazon-linux-ami/"* ]]; then
        sudo initctl restart jupyter-server --no-wait
      else
        sudo systemctl --no-block restart jupyter-server.service
      fi
    EOT
  )
}

################################################################################
# IAM Role
################################################################################

resource "aws_iam_role" "this" {
  name = local.name

  assume_role_policy  = data.aws_iam_policy_document.this.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"]

  inline_policy {
    name = local.name

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ListBucket",
          Effect   = "Allow",
          Action   = ["s3:ListBucket"],
          Resource = [module.s3_bucket.s3_bucket_arn]
        },
        {
          Sid      = "AllObjectActions",
          Effect   = "Allow",
          Action   = "s3:*Object",
          Resource = ["${module.s3_bucket.s3_bucket_arn}/*"]
        }
      ]
    })
  }

  tags = module.tags.tags
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

################################################################################
# Security group
################################################################################

module "sagemaker_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-sagemaker"
  description = "Security group for Sagemaker"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      description = "VPC CIDR HTTPS"
      cidr_blocks = join(",", module.vpc.private_subnets_cidr_blocks)
    },
  ]
  ingress_with_self = [
    {
      description = "All ingress within security group"
      from_port   = 8192
      to_port     = 65535
      protocol    = "tcp"
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      description = "All egress"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = module.tags.tags
}

################################################################################
# S3 Bucket w/ Data Set
################################################################################

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix = "${local.name}-"

  # Allow deletion of non-empty bucket
  # NOTE: This is enabled for example usage only, you should not enable this for production workloads
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = module.tags.tags
}

resource "null_resource" "s3_data" {
  provisioner "local-exec" {
    command = <<-EOT
        curl https://cdn.openai.com/API/examples/data/vector_database_wikipedia_articles_embedded.zip --output embeddings.zip && \
        unzip embeddings.zip -d "embeddings_data" && \
        aws s3 sync embeddings_data s3://${module.s3_bucket.s3_bucket_id}/
    EOT
  }
}
