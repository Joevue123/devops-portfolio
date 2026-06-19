# 21 — Automated Canary Deployments with Flagger

**Tier:** Advanced | **Skills:** Flagger, Istio/Nginx, progressive delivery, automated rollback

## Problem Statement

Manual canary deployments require humans watching dashboards and deciding when to promote. Flagger automates the entire progressive delivery loop — incrementally shifting traffic, analyzing real metrics, and rolling back automatically if error rate or latency degrades.

## Architecture

```
Git push → new image tag in Deployment
                │
                ▼
┌───────────────────────────────────────────────────────────────┐
│  Flagger (controller watching Canary CRDs)                   │
│                                                               │
│  Phase 1: Initialize                                          │
│    Creates api-primary (stable) + api-canary (new version)   │
│    Shifts 0% traffic to canary                               │
│                                                               │
│  Phase 2: Analysis loop (every 1 minute)                      │
│    ┌────────────────────────────────────────────────────┐    │
│    │  Shift traffic: +10% to canary per interval        │    │
│    │                                                    │    │
│    │  Query Prometheus metrics:                         │    │
│    │    ✓ error rate < 1%                               │    │
│    │    ✓ p99 latency < 500ms                           │    │
│    │    ✓ request success rate > 99%                    │    │
│    │                                                    │    │
│    │  PASS → continue shifting (10% → 20% → ... → 100%)│    │
│    │  FAIL → instant rollback to primary, alert Slack   │    │
│    └────────────────────────────────────────────────────┘    │
│                                                               │
│  Phase 3: Promote (all checks passed at 100%)                 │
│    Copies canary spec to primary                              │
│    Scales canary to 0                                         │
│    Deployment complete — zero human intervention              │
└───────────────────────────────────────────────────────────────┘

Traffic split managed by:
  Istio VirtualService weights  (if using Istio provider)
  Nginx Ingress annotations     (if using Nginx provider)
```

## Usage

```bash
# Install Flagger for Nginx
helm repo add flagger https://flagger.app
helm install flagger flagger/flagger \
  -n flagger-system --create-namespace \
  --set meshProvider=nginx \
  --set metricsServer=http://prometheus.monitoring:9090

# Apply Canary resource
kubectl apply -f k8s/canary.yaml -n production

# Trigger a canary run by updating the image
kubectl set image deployment/api api=myapp:v1.3.0 -n production

# Watch Flagger progression
kubectl get canary api -n production -w
kubectl describe canary api -n production

# Check Flagger events
kubectl get events -n production --field-selector reason=Synced
```

## Key Decisions

- **Automated metric gates** — no human approval needed for standard deploys; humans only intervene on failures
- **Prometheus queries as acceptance criteria** — same metrics ops teams watch, codified as pass/fail
- **Webhooks for pre/post promotion** — run integration tests and notify Slack without modifying app code
- **`stepWeight: 10` with `interval: 1m`** — full canary takes 10 minutes; fast enough to ship, slow enough to catch regressions

## Production Considerations

- Add a load test webhook (using `hey` or `k6`) so the canary gets real traffic during analysis, not just ambient load
- Set `skipAnalysis: true` override for hotfixes that can't wait for canary validation
- Use Flagger's A/B testing mode for feature flags (route by header/cookie, not just weight)
- Integrate with DORA metrics — Flagger emits deployment frequency and failure rate automatically

## Metrics for Success

- Canary promotion rate > 90% (tuned thresholds, not overly strict)
- Rollback triggered within 2 minutes of a regression
- Zero manual traffic weight changes needed
