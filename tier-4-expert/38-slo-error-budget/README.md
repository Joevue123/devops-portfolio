# 38 — SLO/Error Budget Tracking with Sloth

Define Service Level Objectives in a declarative YAML format. Sloth generates Prometheus recording rules and multi-window burn rate alert rules following Google SRE Book recommendations. Error budgets are visualized in Grafana.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  SLO Definition (YAML)                                               │
│  ├── sli: good_requests / total_requests                             │
│  ├── objective: 99.9% over 30 days                                   │
│  └── alert: burn rate thresholds                                     │
│                      │                                               │
│                      ▼ sloth generate                                │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Generated Prometheus Rules                                    │  │
│  │  ├── Recording rules (5m, 30m, 1h, 6h, 3d windows)           │  │
│  │  ├── slo:sli_error:ratio_rate5m{sloth_id="api-availability"}  │  │
│  │  └── Alert rules (2 pairs: fast burn + slow burn)             │  │
│  │      ├── ErrorBudgetBurnHigh (1h window, 14.4x burn)          │  │
│  │      └── ErrorBudgetBurnLow  (6h window, 6x burn)             │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                      │                                               │
│              Prometheus scrapes → AlertManager routes                │
│                                                                      │
│  Grafana Dashboard:                                                  │
│  ├── Error budget remaining (%) — 30d rolling                       │
│  ├── Burn rate (current vs. threshold)                               │
│  ├── SLO compliance heatmap (last 90 days)                          │
│  └── Alert history (burn rate spikes)                                │
└──────────────────────────────────────────────────────────────────────┘
```

## Problem Statement

"Is the system up?" is the wrong question. "How much of our error budget have we spent?" drives better engineering decisions: slow down deploy frequency when budget is low, invest in reliability when budget is ample.

## Key Files

```
slos/api-slos.yaml              — Sloth PrometheusServiceLevel CR (availability + latency)
slos/checkout-slos.yaml         — Checkout flow SLOs (payment success rate)
alerts/error-budget-policy.yaml — What to do at different burn rates
grafana/slo-dashboard.json      — Grafana dashboard (importable)
Makefile                        — sloth generate, validate, apply
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Sloth over manual PromQL | Sloth generates correct multi-window rules; manual PromQL is error-prone |
| 30-day rolling window | Industry standard; aligns with monthly business reviews |
| Two-window burn rate alerts | Fast burn (5% budget in 1h) + slow burn (10% in 6h) catches all failure modes |
| 99.9% not 99.99% | 99.9% = 43min downtime/month; 99.99% requires 4x engineering investment |
| Alert on burn rate, not error rate | Burn rate is normalized — 1% error rate at midnight ≠ 1% at peak |

## Usage

```bash
# Install Sloth CLI
curl -L https://github.com/slok/sloth/releases/latest/download/sloth-linux-amd64 \
  -o /usr/local/bin/sloth && chmod +x /usr/local/bin/sloth

# Generate Prometheus rules from SLO definitions
sloth generate -i slos/api-slos.yaml -o /tmp/slo-rules.yaml

# Validate generated rules
promtool check rules /tmp/slo-rules.yaml

# Apply to cluster
kubectl apply -f /tmp/slo-rules.yaml

# Or use the CRD-based workflow (Sloth operator)
kubectl apply -f slos/api-slos.yaml

# Check error budget remaining
kubectl exec -n monitoring prometheus-0 -- promtool query instant \
  'sloth_slo_error_budget_remaining{sloth_id="api-availability"}'
```

## Sample SLO Status

```
SLO: api-availability (99.9% / 30d)
Error Budget: 43m 12s total
  Remaining:  31m 45s (73.5%)
  Spent:      11m 27s (26.5%)

Burn Rate (current):  0.8x  ✓ (below 1x threshold)
Burn Rate (6h):       1.2x  ⚠ Watch
```

## Production Considerations

- **Error budget policy** — document what actions to take at 50%, 25%, 0% remaining
- **SLO review cadence** — review SLO compliance weekly with engineering, monthly with product
- **Multiple SLIs** — availability AND latency SLOs; a slow service isn't "up"
- **Exclude planned maintenance** — use Prometheus label selectors to skip known maintenance windows

## Success Metrics

- SLO compliance: > 99.9% availability measured over 30-day windows
- Alert fatigue: < 1 false positive page per week from SLO burn alerts
- Error budget policy: documented and followed within 30 minutes of budget hitting 25%
