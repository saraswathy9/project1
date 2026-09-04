# variables.tf
# WHY: Never hard-code values inside main.tf. Variables make the same
# code reusable across dev/qa/prod just by changing values.

variable "aws_region" {
  description = "AWS region to deploy into (choose one close to you, free tier works in all)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used to name all resources"
  type        = string
  default     = "devops-demo"
}

variable "vpc_cidr" {
  description = "IP address range for our private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 size for the Jenkins server - t2.micro is AWS Free Tier eligible"
  type        = string
  default     = "t2.micro"
}
