# 06 — Terraform AWS Infrastructure

**Tier:** Foundational | **Skills:** Terraform, AWS VPC, EC2, RDS, remote state, modules

## Problem Statement

Clicking through the AWS console produces snowflake infrastructure — impossible to reproduce, audit, or version control. This project defines a production-ready 3-tier AWS architecture entirely in Terraform, with remote state, locking, and reusable modules.

## Architecture

```
AWS Region (us-east-1)
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  VPC: 10.0.0.0/16                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  Public Subnets (10.0.1.0/24, 10.0.2.0/24)               │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  Internet Gateway  ──►  ALB (Application LB)        │  │  │
│  │  │                         │                           │  │  │
│  │  │  NAT Gateway (AZ-a)     NAT Gateway (AZ-b)          │  │  │
│  │  └──────────────────────────┬──────────────────────────┘  │  │
│  │                             │                             │  │
│  │  Private Subnets (10.0.3.0/24, 10.0.4.0/24)              │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │                     ▼                               │  │  │
│  │  │  Auto Scaling Group                                 │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐                │  │  │
│  │  │  │  EC2 (AZ-a)  │  │  EC2 (AZ-b)  │  t3.medium     │  │  │
│  │  │  └──────────────┘  └──────────────┘                │  │  │
│  │  └─────────────────────────┬───────────────────────────┘  │  │
│  │                             │                             │  │
│  │  Data Subnets (10.0.5.0/24, 10.0.6.0/24)                 │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  RDS PostgreSQL (Multi-AZ)                          │  │  │
│  │  │  Primary (AZ-a) ←sync→ Standby (AZ-b)              │  │  │
│  │  │                                                     │  │  │
│  │  │  ElastiCache Redis (cluster mode)                   │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

Remote State:
  S3 bucket (versioned + encrypted) + DynamoDB lock table
```

## Usage

```bash
# Bootstrap state backend (one-time)
cd bootstrap/
terraform init && terraform apply

# Deploy infrastructure
cd ../
terraform init
terraform workspace new staging
terraform plan -var-file=envs/staging.tfvars
terraform apply -var-file=envs/staging.tfvars

# Destroy staging
terraform destroy -var-file=envs/staging.tfvars

# Format and validate
terraform fmt -recursive
terraform validate
```

## Module Structure

```
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── envs/
│   ├── staging.tfvars
│   └── production.tfvars
├── modules/
│   ├── vpc/          ← VPC, subnets, IGW, NAT, route tables
│   ├── compute/      ← ASG, launch template, ALB, security groups
│   ├── database/     ← RDS, parameter group, subnet group
│   └── cache/        ← ElastiCache, subnet group
└── bootstrap/        ← S3 state bucket + DynamoDB lock
```

## Key Decisions

- **Remote state in S3 + DynamoDB locking** — safe for team use, prevents concurrent apply corruption
- **Workspaces for environments** — staging/production use same code, different `tfvars`
- **NAT Gateway per AZ** — avoids single AZ being a network failure point
- **RDS Multi-AZ** — automatic failover, no manual intervention needed

## Production Considerations

- Use Terragrunt to DRY up multi-environment root module boilerplate
- Add `terraform-docs` to auto-generate module documentation
- Integrate `tfsec` and `checkov` in CI for security policy enforcement
- Tag all resources with `Environment`, `Owner`, `CostCenter` for FinOps

## Metrics for Success

- `terraform plan` produces 0 changes on stable environments
- Infrastructure provisioning time < 15 minutes
- Zero manually created AWS resources (detected by AWS Config drift detection)
