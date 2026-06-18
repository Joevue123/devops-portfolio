terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "portfolio/06-aws-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-portfolio"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  name            = "${var.project_name}-${var.environment}"
  cidr            = var.vpc_cidr
  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs
  data_subnets    = var.data_subnet_cidrs
}

module "compute" {
  source = "./modules/compute"

  name              = "${var.project_name}-${var.environment}"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type     = var.instance_type
  min_size          = var.asg_min_size
  max_size          = var.asg_max_size
  desired_capacity  = var.asg_desired_capacity
  ami_id            = data.aws_ami.amazon_linux_2023.id
}

module "database" {
  source = "./modules/database"

  name             = "${var.project_name}-${var.environment}"
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.data_subnet_ids
  allowed_sg_id    = module.compute.app_security_group_id
  instance_class   = var.db_instance_class
  engine_version   = "16.3"
  database_name    = var.db_name
  master_username  = var.db_master_username
  multi_az         = var.environment == "production"
}

module "cache" {
  source = "./modules/cache"

  name          = "${var.project_name}-${var.environment}"
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.data_subnet_ids
  allowed_sg_id = module.compute.app_security_group_id
  node_type     = var.redis_node_type
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
