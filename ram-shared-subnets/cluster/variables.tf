variable "assume_role_arn" {
  description = "The ARN of the role that Terraform will assume to deploy the infrastructure"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC containing the RAM shared subnets"
  type        = string
}
