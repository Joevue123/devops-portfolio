terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "multi-region/${terraform.workspace}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "primary" {
  type    = bool
  default = true
  description = "true for primary region (RDS writer), false for secondary"
}

variable "environment" {
  type    = string
  default = "production"
}

locals {
  regions = {
    primary   = "us-east-1"
    secondary = "eu-west-1"
  }
  az_count   = 3
  cluster_version = "1.30"
}

# Primary region provider
provider "aws" {
  alias  = "primary"
  region = local.regions.primary
}

# Secondary region provider
provider "aws" {
  alias  = "secondary"
  region = local.regions.secondary
}

# ── Per-region infra ──────────────────────────────────────────────────────────

module "us_east_1" {
  source = "./modules/region"
  providers = {
    aws = aws.primary
  }

  region      = local.regions.primary
  environment = var.environment
  is_primary  = true
  az_count    = local.az_count
  eks_version = local.cluster_version

  rds_global_cluster_id = aws_rds_global_cluster.main.id
  rds_engine_version    = "15.4"
}

module "eu_west_1" {
  source = "./modules/region"
  providers = {
    aws = aws.secondary
  }

  region      = local.regions.secondary
  environment = var.environment
  is_primary  = false
  az_count    = local.az_count
  eks_version = local.cluster_version

  rds_global_cluster_id = aws_rds_global_cluster.main.id
  rds_engine_version    = "15.4"

  depends_on = [module.us_east_1]    # primary must exist before adding replica
}

# ── RDS Global Database (primary in us-east-1, replica in eu-west-1) ─────────

resource "aws_rds_global_cluster" "main" {
  provider                  = aws.primary
  global_cluster_identifier = "${var.environment}-global"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  database_name             = "appdb"
  deletion_protection       = true

  lifecycle {
    prevent_destroy = true
  }
}

# ── Route53 latency routing + health checks ───────────────────────────────────

resource "aws_route53_zone" "main" {
  provider = aws.primary
  name     = "example.com"
}

resource "aws_route53_health_check" "us_east_1" {
  provider          = aws.primary
  fqdn              = module.us_east_1.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = "2"
  request_interval  = "10"

  tags = { Name = "us-east-1-health" }
}

resource "aws_route53_health_check" "eu_west_1" {
  provider          = aws.primary
  fqdn              = module.eu_west_1.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = "2"
  request_interval  = "10"

  tags = { Name = "eu-west-1-health" }
}

# Latency routing — us-east-1
resource "aws_route53_record" "api_us" {
  provider        = aws.primary
  zone_id         = aws_route53_zone.main.zone_id
  name            = "api.example.com"
  type            = "A"
  set_identifier  = "us-east-1"
  health_check_id = aws_route53_health_check.us_east_1.id

  latency_routing_policy {
    region = "us-east-1"
  }

  alias {
    name                   = module.us_east_1.alb_dns_name
    zone_id                = module.us_east_1.alb_zone_id
    evaluate_target_health = true
  }
}

# Latency routing — eu-west-1
resource "aws_route53_record" "api_eu" {
  provider        = aws.primary
  zone_id         = aws_route53_zone.main.zone_id
  name            = "api.example.com"
  type            = "A"
  set_identifier  = "eu-west-1"
  health_check_id = aws_route53_health_check.eu_west_1.id

  latency_routing_policy {
    region = "eu-west-1"
  }

  alias {
    name                   = module.eu_west_1.alb_dns_name
    zone_id                = module.eu_west_1.alb_zone_id
    evaluate_target_health = true
  }
}
