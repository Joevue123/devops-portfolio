# 48 — Platform Engineering KPIs Dashboard

Measure what matters for a platform team: adoption metrics, golden signal SLOs, developer experience NPS, and operational efficiency. Grafana dashboard gives platform leads a single pane showing platform health and team impact.

## Architecture

```
Data Sources:
┌─────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────┐
│  Kubernetes API │ │  GitHub API      │ │  Backstage API   │ │  Surveys │
│  (adoption)     │ │  (DORA, CI time) │ │  (catalog count) │ │  (NPS)   │
└────────┬────────┘ └────────┬─────────┘ └────────┬─────────┘ └────┬─────┘
         └──────────────────────────────────────────────────────────┘
                              │
                   ┌──────────▼──────────┐
                   │  Prometheus +        │
                   │  Pushgateway         │
                   └──────────┬──────────┘
                              │
                   ┌──────────▼──────────┐
                   │  Grafana Dashboard  │
                   │                     │
                   │  Platform KPIs:     │
                   │  ├── Adoption       │
                   │  ├── Golden Signals │
                   │  ├── DevEx          │
                   │  └── Efficiency     │
                   └─────────────────────┘
```

## Platform KPIs (Four Categories)

### 1. Adoption
- % services using golden path template (target: > 80%)
- % services registered in Backstage catalog (target: > 95%)
- % services using approved container base images (target: 100%)
- vCluster adoption: teams using self-service vs. tickets

### 2. Platform Reliability (Golden Signals)
- Platform API availability: > 99.9%
- ArgoCD sync success rate: > 99.5%
- Vault secret availability: > 99.99%
- CI pipeline availability: > 99.5%

### 3. Developer Experience
- P50/P95 time-to-first-deploy for new services (target: < 30 min)
- CI pipeline duration trend (target: < 10 min)
- Platform NPS score (quarterly survey, target: > 40)
- Support ticket volume (platform-related, target: decreasing MoM)

### 4. Operational Efficiency
- Platform team toil ratio (% time on reactive work, target: < 30%)
- Cost per team environment (target: < $100/mo)
- MTTR for platform incidents (target: < 30 min)
- Automation rate: % of provisioning requests fulfilled without human touch

## Key Files

```
k8s/kpi-collector-cronjob.yaml  — CronJob collecting adoption metrics
k8s/prometheus-rules.yaml       — Recording rules for KPI aggregation
grafana/platform-kpis.json      — Grafana dashboard (importable)
scripts/nps-export.sh           — Export NPS survey results to Prometheus
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Platform team measures its own KPIs | Accountability — platform is a product, not just infrastructure |
| Developer experience NPS | Lagging indicator of adoption; qualitative alongside quantitative |
| Separate from product DORA | Platform DORA (platform team's own deploys) ≠ product DORA |
| Weekly automated report | Managers see trend without pulling dashboards; surfaces regressions |
| Toil tracking via time logs | Quantifies ROI of automation investments |

## Production Considerations

- **Avoid vanity metrics** — "number of clusters managed" without adoption context is meaningless
- **Benchmark externally** — DORA report provides industry percentiles for comparison
- **Tie KPIs to OKRs** — platform KPIs should map to company-level engineering OKRs
- **Quarterly review** — KPIs should evolve as platform matures

## Success Metrics (example targets)

| KPI | Current | 6-month Target |
|-----|---------|----------------|
| Golden path adoption | 45% | 80% |
| New service deploy time | 2 hours | 30 minutes |
| Platform NPS | 22 | 40 |
| Platform toil | 55% | 30% |
| Cost per environment | $180/mo | $80/mo |
