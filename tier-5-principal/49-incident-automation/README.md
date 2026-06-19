# 49 — Incident Response Automation

Automated incident response: PagerDuty webhook triggers runbook execution, creates a Slack war-room channel, silences non-critical alerts, and runs diagnostic scripts. Post-incident: auto-generates timeline and draft post-mortem.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Incident Trigger                                                    │
│  PagerDuty incident.triggered webhook                                │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Incident Bot (Python, runs in Kubernetes)                           │
│                                                                      │
│  On TRIGGERED:                                                       │
│  1. Create Slack channel #incident-{id}-{service}                    │
│  2. Invite on-call engineer + team leads                             │
│  3. Post: incident summary, affected service, runbook link           │
│  4. Silence related low-priority alerts (30 min)                     │
│  5. Run auto-diagnosis: check error rate, recent deploys, pod status │
│  6. Post diagnostic summary to Slack channel                         │
│                                                                      │
│  On RESOLVED:                                                        │
│  1. Post resolution summary to channel                               │
│  2. Extract timeline from Slack channel history                      │
│  3. Create GitHub issue with post-mortem template (pre-filled)       │
│  4. Archive Slack channel after 7 days                               │
│                                                                      │
│  Runbooks (structured YAML):                                         │
│  ├── high-error-rate.yaml     → check pods, recent deploy, rollback  │
│  ├── database-latency.yaml    → check connections, slow queries      │
│  └── pod-crashloop.yaml       → get logs, describe pod, check OOM   │
└──────────────────────────────────────────────────────────────────────┘
```

## Problem Statement

An on-call engineer at 2am wastes the first 5 minutes finding the runbook, creating a Slack channel, and silencing noise. This automation gives them a pre-populated war-room with diagnostic data already gathered — reducing MTTR by 30-50%.

## Key Files

```
scripts/incident-bot.py        — webhook handler + Slack + auto-diagnosis
runbooks/high-error-rate.yaml  — structured runbook with automated steps
runbooks/pod-crashloop.yaml    — pod crashloop diagnostics runbook
k8s/incident-bot.yaml          — Deployment + Service + PodMonitor
scripts/post-mortem.sh         — generate post-mortem template from incident data
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Webhook-driven over polling | < 1 second from PagerDuty alert to Slack channel creation |
| Structured runbooks (YAML) | Machine-readable steps enable partial automation; human-readable for on-call |
| Auto-silence related alerts | Reduces noise during incident; avoids alert storm distracting responders |
| Post-mortem auto-generation | Pre-fill timeline from Slack; responders add RCA, not reconstruct timeline |
| Run in Kubernetes with kubeconfig | Bot needs cluster access for diagnostics (`kubectl get pods`, `kubectl logs`) |

## Usage

```bash
# Deploy incident bot
kubectl apply -f k8s/incident-bot.yaml

# Configure PagerDuty webhook
# PagerDuty → Service → Webhooks → Add V3 Webhook
# URL: https://incident-bot.internal/webhook/pagerduty
# Events: incident.triggered, incident.resolved

# Test with simulated webhook
curl -X POST http://localhost:8080/webhook/pagerduty \
  -H 'Content-Type: application/json' \
  -d @tests/fixtures/incident-triggered.json

# Manual post-mortem generation
./scripts/post-mortem.sh \
  --incident-id P123456 \
  --start "2026-06-19T02:00:00Z" \
  --end "2026-06-19T02:45:00Z" \
  --service payment-api
```

## Runbook Example

```yaml
# runbooks/high-error-rate.yaml
name: High Error Rate
triggers: [high_error_rate, api_error_budget_burn]
automated_steps:
  - name: Check recent deployments
    command: |
      kubectl rollout history deployment/api -n production | tail -5
  - name: Get current error rate
    command: |
      kubectl exec -n monitoring prometheus-0 -- promtool query instant \
        'sum(rate(http_requests_total{code=~"5..",job="api"}[5m]))'
  - name: Check pod status
    command: |
      kubectl get pods -n production -l app=api
manual_steps:
  - "If recent deploy: kubectl rollout undo deployment/api -n production"
  - "Check Datadog APM for slow traces"
  - "Page DBA if database connection errors > 20%"
```

## Production Considerations

- **Runbook versioning** — runbooks in Git; incident bot always uses latest main
- **Idempotency** — re-triggering the same incident doesn't create duplicate channels
- **Permissions** — incident bot has read-only K8s access; rollback requires human confirmation
- **Blameless culture** — post-mortem template emphasizes system failures, not individual errors

## Success Metrics

- War-room creation time: < 30 seconds from PagerDuty trigger
- Diagnostic data in channel: < 2 minutes from incident trigger
- MTTR reduction: 30% improvement (measured over 6 months)
- Post-mortem completion rate: > 90% within 5 business days
