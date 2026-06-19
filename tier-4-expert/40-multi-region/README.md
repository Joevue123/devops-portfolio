# 40 — Multi-Region Active-Active Architecture

Deploy the same application stack in two AWS regions (us-east-1 + eu-west-1) with Route53 latency routing directing users to the nearest region. RDS Global Database provides < 1 second cross-region replication. Automatic failover in < 60 seconds.

## Architecture

```
                        ┌──────────────────┐
                        │   Users (Global) │
                        └────────┬─────────┘
                                 │ DNS query: api.example.com
                                 ▼
                    ┌────────────────────────┐
                    │  Route53               │
                    │  Latency routing +     │
                    │  Health check failover │
                    └──────┬──────────┬──────┘
                           │          │
               ┌───────────┴──┐   ┌───┴──────────────┐
               │ us-east-1    │   │ eu-west-1         │
               │              │   │                   │
               │ ALB          │   │ ALB               │
               │  ↓           │   │  ↓                │
               │ EKS Cluster  │   │ EKS Cluster       │
               │  ↓           │   │  ↓                │
               │ RDS Primary  │──▶│ RDS Read Replica  │
               │ (write)      │   │ (read, failover)  │
               │              │   │                   │
               │ S3 Bucket    │   │ S3 Bucket         │
               │  ↕ CRR       │   │  ↕ CRR            │
               └──────────────┘   └───────────────────┘
                                        │
                        Cross-Region Replication (CRR)
                        RDS Global Database: <1s RPO
                        S3 Cross-Region Replication
```

## Problem Statement

A single-region deployment fails completely during AWS regional outages (which happen). Active-active with Route53 latency routing reduces both latency for global users AND provides automatic failover — without manual intervention.

## Key Files

```
terraform/main.tf                  — root module: multi-region providers
terraform/modules/region/main.tf   — per-region: EKS, ALB, RDS, S3
terraform/modules/region/outputs.tf
terraform/global/route53.tf        — Route53 health checks + latency routing
terraform/global/rds-global.tf     — RDS Global Database cluster
scripts/failover.sh                — Promote secondary RDS + update Route53
scripts/verify-replication.sh      — Check RDS replication lag
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Active-active over active-passive | Users in EU get low latency from EU region, not just failover |
| Route53 latency routing | Routes to lowest-latency region automatically |
| RDS Global Database over multi-region reads | < 1s replication, 1-minute promotion time, single write endpoint |
| S3 Cross-Region Replication | Static assets, user uploads available globally without redirect |
| Separate Terraform workspaces per region | Region isolation — us-east-1 Terraform failure doesn't affect EU |

## Usage

```bash
# Deploy both regions
terraform -chdir=terraform init
terraform -chdir=terraform workspace new us-east-1
terraform -chdir=terraform apply -var="region=us-east-1" -var="primary=true"

terraform -chdir=terraform workspace new eu-west-1
terraform -chdir=terraform apply -var="region=eu-west-1" -var="primary=false"

# Verify replication
./scripts/verify-replication.sh

# Regional failover (manual — e.g., us-east-1 outage)
./scripts/failover.sh --promote eu-west-1

# Verify Route53 health checks
aws route53 list-health-checks --query 'HealthChecks[*].{ID:Id,Status:HealthCheckConfig.Type}'
```

## Failover Runbook

```
1. Detect: Route53 health check fails us-east-1 ALB (< 10s detection)
2. Auto:   Route53 removes us-east-1 from DNS (< 60s TTL propagation)
3. Auto:   All traffic routes to eu-west-1 (no manual DNS change)
4. Manual: Promote eu-west-1 RDS read replica to primary
           aws rds failover-global-cluster --global-cluster-id my-global
5. Verify: Write endpoint now points to eu-west-1 RDS
6. Notify: PagerDuty → on-call SRE
```

## Production Considerations

- **Database write routing** — application must handle write endpoint changes on promotion
- **Session affinity** — if users have sessions, Route53 sticky sessions prevent cross-region session loss
- **Data residency** — EU data regulations may prohibit replicating EU user data to US; use separate RDS per region
- **Cost** — active-active doubles infrastructure cost; validate ROI with SLA requirements

## Success Metrics

- RTO (Recovery Time Objective): < 60 seconds (Route53 failover + DNS TTL)
- RPO (Recovery Point Objective): < 1 second (RDS Global Database replication lag)
- Global p99 latency: < 200ms (users routed to nearest region)
- Monthly test: automated failover drill, validated with monitoring
