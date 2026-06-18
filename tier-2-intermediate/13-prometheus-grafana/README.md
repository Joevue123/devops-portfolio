# 13 — Prometheus + Grafana Observability Stack

**Tier:** Intermediate | **Skills:** Prometheus, Grafana, AlertManager, PromQL, ServiceMonitor

## Problem Statement

You can't fix what you can't see. This project deploys a full observability stack: Prometheus scrapes metrics from services and the cluster, AlertManager routes alerts to the right team, and Grafana visualizes everything with pre-built dashboards and SLO tracking.

## Architecture

```
Metric Sources
┌────────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                            │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │  Your API    │  │  node-       │  │  kube-state-         │ │
│  │  /metrics    │  │  exporter    │  │  metrics             │ │
│  │  (Prom SDK)  │  │  (host CPU/  │  │  (pod/deploy counts) │ │
│  └──────┬───────┘  │  mem/disk)   │  └──────────┬───────────┘ │
│         │          └──────┬───────┘             │             │
│         └─────────────────┼─────────────────────┘             │
│                           │ ServiceMonitor CRD                 │
│                           │ (tells Prometheus what to scrape)  │
└───────────────────────────┼────────────────────────────────────┘
                            │
                            ▼ scrape every 15s
┌────────────────────────────────────────────────────────────────┐
│                     Prometheus                                 │
│                                                               │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Recording Rules  ← pre-compute expensive PromQL        │ │
│  │  Alert Rules      ← fire when thresholds breached       │ │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │ FIRING alerts                   │
└─────────────────────────────┼──────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    AlertManager                                │
│                                                               │
│  Routes:                                                      │
│    severity=critical → PagerDuty (immediate page)             │
│    severity=warning  → Slack #alerts                          │
│    severity=info     → email digest                           │
│                                                               │
│  Inhibit: if cluster is down, silence all pod alerts          │
│  Silence: maintenance windows                                 │
└─────────────────────────────┬──────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                      Grafana :3000                             │
│                                                               │
│  Dashboards:                                                  │
│    • API Overview     — RPS, latency p50/p95/p99, error rate  │
│    • Node Resources   — CPU, memory, disk per node            │
│    • K8s Workloads    — pod restarts, OOMKills, pending pods  │
│    • SLO Dashboard    — error budget burn rate                │
└────────────────────────────────────────────────────────────────┘
```

## Usage

```bash
# Deploy with Docker Compose (local)
docker compose up -d

# Or deploy kube-prometheus-stack via Helm (production)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f values.yaml

# Apply custom alert rules
kubectl apply -f prometheus/rules/ -n monitoring

# Query Prometheus
curl 'http://localhost:9090/api/v1/query?query=rate(http_requests_total[5m])'

# Open Grafana (default: admin/admin — change immediately)
open http://localhost:3000
```

## Key Decisions

- **ServiceMonitor CRDs** over static `scrape_configs` — teams own their own scrape config via Kubernetes objects
- **Recording rules for SLO math** — pre-compute `job:request_latency_seconds:mean5m` so dashboards load fast
- **Alert on symptoms, not causes** — alert on error rate > 1%, not on CPU > 80%
- **AlertManager inhibition rules** — suppress noisy downstream alerts when root cause is already firing

## Production Considerations

- Use Thanos or Mimir for long-term metric storage (Prometheus local retention: 15 days max)
- Enable remote_write to a managed service (Grafana Cloud, Datadog) for durability
- Set `--storage.tsdb.retention.size` to prevent disk exhaustion
- Use `PrometheusRule` CRDs so alert rules live in Git alongside the apps they monitor

## Metrics for Success

- Alert noise < 5 non-actionable pages per week
- Dashboard load time < 2 seconds for 24h range queries
- SLO error budget visibility updated every 5 minutes
