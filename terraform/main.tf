# main.tf
# WHY Terraform: Instead of clicking around the AWS Console (slow, not
# repeatable, easy to forget a step), we describe the infrastructure we
# WANT in code. Terraform compares this to what exists and creates/changes
# only the difference. This is "Infrastructure as Code" (IaC).
#
# WHAT this file builds:
#   1. A VPC (our own private network inside AWS)
#   2. Public subnets (so resources can reach the internet)
#   3. An EC2 instance to run Jenkins on (Free Tier: t2.micro, 750 hrs/month free)
#   4. An ECR repository (private Docker registry to store our images)
#   5. Security Group (firewall rules)
#
# NOTE: The EKS cluster itself is created separately in eks.tf below,
# because EKS control plane is NOT free (~$0.10/hr) - see README for the
# free-tier-friendly alternative (minikube/kind) vs the real EKS steps.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. VPC - our isolated network
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

# 2. Public subnet - EC2/EKS nodes launch here
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.1.0/24"
  map_public_ip_on_launch  = true
  availability_zone        = "${var.aws_region}a"
  tags = { Name = "${var.project_name}-public-subnet" }
}

# 3. Internet Gateway - lets the VPC talk to the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 4. Security Group - firewall: allow SSH(22), Jenkins UI(8080), HTTP(80)
resource "aws_security_group" "jenkins_sg" {
  name   = "${var.project_name}-jenkins-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # In real projects, restrict this to your own IP only
  }
  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-sg" }
}

# 5. EC2 instance - this is where Jenkins will be installed (by Ansible, next step)
resource "aws_instance" "jenkins_server" {
  ami                    = "ami-0c02fb55956c7d316" # Amazon Linux 2 (us-east-1) - check latest AMI for your region
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name                = "your-ec2-keypair"   # create this in AWS Console > EC2 > Key Pairs first

  tags = { Name = "${var.project_name}-jenkins-server" }
}

# 6. ECR - private Docker image registry (Free Tier: 500MB storage/month free)
resource "aws_ecr_repository" "app_repo" {
  name                 = "devops-demo-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true   # ECR automatically scans images for vulnerabilities
  }
}
