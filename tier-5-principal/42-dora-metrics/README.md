# 42 — DORA Metrics & Engineering Analytics

Measure the four DORA key metrics — Deployment Frequency, Lead Time for Changes, Mean Time to Recovery (MTTR), and Change Failure Rate — by instrumenting GitHub Actions, PagerDuty, and your Kubernetes deployment pipeline.

## Architecture

```
Data Sources:
┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐
│  GitHub Actions │  │   PagerDuty      │  │   ArgoCD        │
│  (deploy events)│  │   (incidents)    │  │   (sync events) │
└────────┬────────┘  └────────┬─────────┘  └────────┬────────┘
         │                    │                      │
         └────────────────────┼──────────────────────┘
                              │ webhook / API poll
                              ▼
                  ┌───────────────────────┐
                  │  dora-collector       │
                  │  (Python service)     │
                  │  Pushes to Prometheus │
                  └───────────┬───────────┘
                              │
                  ┌───────────▼──────────┐
                  │  Prometheus          │
                  │  dora_deployments    │
                  │  dora_lead_time_secs │
                  │  dora_mttr_secs      │
                  │  dora_change_fail    │
                  └───────────┬──────────┘
                              │
                  ┌───────────▼──────────┐
                  │  Grafana Dashboard   │
                  │  Weekly/monthly view │
                  │  Per-team breakdown  │
                  │  Elite/High/Med/Low  │
                  └──────────────────────┘

DORA Performance Bands:
Elite: DF > daily, LT < 1h, MTTR < 1h, CFR < 5%
High:  DF weekly, LT < 1d, MTTR < 1d, CFR < 10%
```

## Problem Statement

Engineering managers need objective data to answer "are we getting faster?" and "are we getting more reliable?". DORA metrics are the industry standard — four numbers that predict organizational performance.

## Key Files

```
scripts/dora-collector.py      — polls GitHub + PagerDuty, pushes to Pushgateway
k8s/collector-cronjob.yaml     — runs collector every 15 minutes
k8s/prometheus-rules.yaml      — recording rules for 7/30/90 day windows
grafana/dora-dashboard.json    — Grafana dashboard (importable)
scripts/weekly-report.sh       — Slack digest of DORA metrics vs. last week
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Prometheus Pushgateway over scraping | Collector runs on schedule; push model fits better than pull |
| GitHub API for lead time | Measures commit timestamp → deploy timestamp automatically |
| PagerDuty for MTTR | Incident open/close timestamps give accurate recovery time |
| Per-team labels | Team-level DORA avoids averages hiding underperforming teams |
| 30-day rolling window | Smooths out weekly variation; used in annual reviews |

## DORA Definitions (this implementation)

- **Deployment Frequency**: count of successful production deploys per day (ArgoCD sync events)
- **Lead Time**: median time from first commit in PR → production deploy (GitHub API)
- **MTTR**: median time from PagerDuty incident created → resolved, for P1/P2 incidents
- **Change Failure Rate**: % of deploys that triggered a P1/P2 incident within 1 hour

## Usage

```bash
# Set up environment
export GITHUB_TOKEN=ghp_xxxx
export PAGERDUTY_TOKEN=xxxx
export PUSHGATEWAY_URL=http://prometheus-pushgateway:9091
export ORG=myorg

# Run collector (or deploy as CronJob)
python scripts/dora-collector.py --since 30d --team payments

# Check current metrics
curl -s http://prometheus:9090/api/v1/query \
  --data-urlencode 'query=dora_deployment_frequency_per_day{team="payments"}' | jq .

# Weekly Slack report
./scripts/weekly-report.sh
```

## Production Considerations

- **Exclude hotfix deploys from Lead Time** — hotfixes distort the metric; tag them separately
- **Exclude planned maintenance from MTTR** — maintenance windows shouldn't count as incidents
- **Automated weekly digest** — managers get numbers without pulling dashboards
- **Historical baseline** — capture Day 1 metrics; show trend over 12 months

## Success Metrics (target for this platform)

- Deployment Frequency: ≥ 1/day (High tier)
- Lead Time: < 1 day
- MTTR: < 4 hours
- Change Failure Rate: < 5%
