# 46 — Cloud Cost Optimization Framework

Systematic approach to reducing AWS spend: Reserved Instance and Savings Plan purchasing automation, Spot instance migration for stateless workloads, right-sizing recommendations from Kubecost, and scheduled scale-down of non-production environments.

## Architecture

```
Cost Optimization Pillars:

1. Commitment Discounts (40-60% savings)
   ├── EC2 Savings Plans — 1yr compute commitment, 40% vs on-demand
   ├── RDS Reserved Instances — 1yr for production databases
   └── ElastiCache Reserved — 1yr for production Redis
   Tool: AWS Cost Explorer + automation scripts

2. Spot Instances (60-80% savings on stateless compute)
   ├── EKS worker nodes: Spot pool of c5, m5, r5 across 3 AZs
   ├── Karpenter: automatic spot → on-demand fallback
   └── Spot interruption handler: 2-minute graceful drain

3. Right-sizing (15-30% savings)
   ├── Kubecost: identifies over-provisioned containers
   ├── VPA: automatic CPU/memory request adjustment
   └── EC2 Compute Optimizer: node size recommendations

4. Scheduling (up to 70% savings on non-prod)
   ├── CronJob: scale dev/staging to 0 replicas at 8pm
   ├── CronJob: scale back up at 7am
   └── Karpenter: scale-to-zero removes underlying EC2

Monthly Savings Dashboard (Grafana):
├── On-demand vs. committed cost ratio
├── Spot savings realized vs. potential
├── Top 10 waste opportunities
└── Cost trend by team / namespace
```

## Problem Statement

AWS bills grow 20-40% per year without active cost management. Most savings come from three levers: commit to predictable workloads (RIs/SPs), use Spot for volatile workloads, and turn off non-production at night. This framework automates all three.

## Key Files

```
terraform/savings-plans.tf       — Savings Plan purchase automation (Terraform)
scripts/spot-migration.sh        — Migrate node group from on-demand to Spot
scripts/schedule-scale.sh        — Scale dev/staging namespaces down at night
scripts/rightsizing-report.sh    — Weekly rightsizing report from Kubecost API
scripts/waste-finder.sh          — Find idle resources: unattached EBS, old snapshots
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Compute Savings Plans over EC2 Reserved | More flexible — applies to any instance type, size, OS |
| 1-year term over 3-year | Better flexibility; recalibrate annually as workloads change |
| Spot for worker nodes, on-demand for system nodes | System pods (CoreDNS, etc.) need stability |
| Schedule-based scale-down over always-on | Dev/staging unused 14h/day → 58% reduction in compute |
| VPA in recommendation mode first | Observe before auto-applying; validate recommendations first |

## Savings Calculator

```
Before optimization (typical):
  EC2 (on-demand):     $8,000/mo
  RDS (on-demand):     $2,000/mo
  ElastiCache:         $800/mo
  TOTAL:               $10,800/mo

After optimization:
  EC2: 60% Spot + 40% SP    → $8,000 × 0.4 × 0.6 + $8,000 × 0.6 × 0.45 = $4,080
  RDS: 1yr Reserved         → $2,000 × 0.60 = $1,200
  ElastiCache: 1yr Reserved → $800 × 0.55 = $440
  Dev/staging -58%          → (included in above)
  TOTAL:                    ~$5,720/mo

  Annual savings: ~$61,000
```

## Usage

```bash
# Find idle resources
./scripts/waste-finder.sh --region us-east-1

# Get rightsizing recommendations
./scripts/rightsizing-report.sh --namespace production --min-savings 50

# Migrate a node group to Spot
./scripts/spot-migration.sh --cluster production --nodegroup general --dry-run

# Set up dev environment scheduling
kubectl apply -f k8s/scale-schedule.yaml

# Review Savings Plan recommendation
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS
```

## Production Considerations

- **Spot interruption budget** — never > 40% Spot in a single node group; always have on-demand fallback
- **RI coverage tracking** — alert when on-demand hours exceed committed coverage
- **Quarterly business review** — compare actual vs. committed spend, adjust Savings Plans
- **Tag compliance** — 100% resource tagging enables accurate team-level chargeback

## Success Metrics

- Spot utilization: > 60% of worker node compute-hours on Spot
- RI/SP coverage: > 80% of steady-state compute hours committed
- Non-production overnight cost: near $0 (scale-to-zero)
- Monthly cost efficiency score: actual spend / (on-demand equivalent) < 0.55
