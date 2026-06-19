# 33 — FinOps Dashboard with Kubecost

Deploy Kubecost for real-time Kubernetes cost visibility: allocate spend by team/namespace/label, set budget alerts, generate rightsizing recommendations, and expose a Grafana dashboard for engineering managers.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                              │
│                                                                  │
│  Kubecost (cost-analyzer pod)                                    │
│  ├── Prometheus (scrapes node metrics)                           │
│  ├── cost-model — maps resource usage to AWS pricing             │
│  └── frontend — Cost Explorer UI                                 │
│                                                                  │
│  Cost Allocation Sources:                                        │
│  ├── Node cost      ← EC2 on-demand + spot pricing API           │
│  ├── PV cost        ← EBS gp3 price per GB                       │
│  ├── Network cost   ← cross-AZ data transfer                     │
│  ├── LoadBalancer   ← ELB hourly cost                            │
│  └── GPU            ← p3/g4 instance overhead                    │
│                                                                  │
│  Reports:                                                        │
│  ├── Namespace breakdown (per team)                              │
│  ├── Label-based (cost-center, service, environment)             │
│  ├── Idle cost (CPU reserved but not used)                       │
│  └── Savings recommendations (rightsize / spot candidates)       │
│                                                                  │
│  Grafana Dashboards:                                             │
│  ├── Weekly cost trend per team                                  │
│  ├── Budget burn rate                                            │
│  └── Rightsizing opportunity heatmap                             │
└──────────────────────────────────────────────────────────────────┘
```

## Problem Statement

Engineering managers want to know what their service costs per month. Platform teams want to detect idle spend and over-provisioned workloads before the AWS bill arrives. Kubecost gives per-minute cost attribution without waiting for the next billing cycle.

## Key Files

```
k8s/kubecost-values.yaml       — Helm values (AWS pricing, retention, OIDC)
k8s/budget-alert.yaml          — Kubecost Budget CRD alerting on overage
grafana/cost-dashboard.json    — Grafana dashboard for team leads
scripts/cost-report.sh         — Weekly cost report to Slack via Kubecost API
scripts/rightsize.sh           — Fetch and print rightsizing recommendations
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Kubecost over AWS Cost Explorer | Per-pod/namespace granularity vs. per-service |
| Enable spot instance awareness | Spot costs 70% less — attribution must reflect actual price paid |
| 30-day Prometheus retention in Kubecost | Enough for monthly reporting without large storage costs |
| Label-based allocation (`cost-center`) | Chargeback to business units, not just K8s namespaces |
| Grafana integration | Engineering leads already live in Grafana — no new tool to adopt |

## Usage

```bash
# Deploy Kubecost
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm upgrade --install kubecost kubecost/cost-analyzer \
  --namespace kubecost --create-namespace \
  -f k8s/kubecost-values.yaml

# Access UI
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090

# Run weekly report
./scripts/cost-report.sh

# Get rightsizing recommendations
./scripts/rightsize.sh --namespace production --min-savings 20
```

## Sample Output

```
Weekly Cost Report — Week of 2026-06-09
────────────────────────────────────────
Namespace         Cost     vs Last Week
production        $1,240   +8%   ⚠
staging           $380     -12%  ✓
monitoring        $95      +2%   ✓
TOTAL             $1,715   +4%

Top rightsizing opportunities:
  api-deployment: reduce CPU limit 4→1 core  → save $180/mo
  worker-job:     move to spot               → save $240/mo
```

## Production Considerations

- **Shared cost allocation** — cluster overhead (monitoring, DNS) split proportionally across namespaces
- **Budget enforcement** — Kubecost Budget alerts before teams overspend, not after
- **Cloud integration** — connect AWS CUR (Cost and Usage Report) for exact pricing vs. estimates
- **Chargeback automation** — export monthly costs to internal billing system via Kubecost API

## Success Metrics

- Cost visibility latency: < 5 minutes (vs. 24-hour delay in AWS Cost Explorer)
- Idle resource waste reduced by 30% within 90 days of adoption
- 100% of namespaces have a team label for attribution
