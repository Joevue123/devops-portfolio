# 37 — Falco Runtime Security

Falco uses eBPF probes to watch kernel syscalls and detect runtime threats: shell spawned in container, unexpected outbound connections, sensitive file reads, privilege escalations. Alerts route to Slack via Falcosidekick.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Kubernetes Nodes (DaemonSet)                                        │
│                                                                      │
│  Falco (eBPF probe in kernel)                                        │
│  ├── Watches: syscalls, /proc, socket events                         │
│  ├── Evaluates rules against event stream                            │
│  └── Emits alerts when rules match                                   │
│                                                                      │
│  Custom Rules:                                                       │
│  ├── shell-in-container        (Critical) — exec bash/sh in pod     │
│  ├── unexpected-outbound       (High) — egress to unknown IP        │
│  ├── read-sensitive-file       (High) — /etc/shadow, /etc/passwd    │
│  ├── write-etc                 (Critical) — any write to /etc/      │
│  ├── crypto-miner-detected     (Critical) — known miner process     │
│  └── k8s-secret-access-anomaly (High) — unusual Secret API calls   │
│                                                                      │
│  Falcosidekick:                                                      │
│  ├── Slack (Critical + High)                                         │
│  ├── PagerDuty (Critical)                                            │
│  └── Prometheus metrics (falco_events_total by priority/rule)        │
└──────────────────────────────────────────────────────────────────────┘
```

## Problem Statement

Container images are scanned before deployment, but runtime behavior is unverified. An attacker who exploits an app vuln at 2am won't be caught by image scanning — only runtime detection catches lateral movement, data exfiltration, and cryptomining.

## Key Files

```
k8s/falco-values.yaml          — Helm values (eBPF driver, sidekick config)
rules/custom-rules.yaml        — Organization-specific detection rules
k8s/falcosidekick.yaml         — Alert routing (Slack, PagerDuty, Prometheus)
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| eBPF driver over kernel module | No kernel module signing required; works on GKE/EKS managed nodes |
| Custom rules over only default rules | Default rules are noisy; tune to environment to reduce false positives |
| Falcosidekick for alert routing | Avoids writing custom webhook code; supports 50+ output targets |
| allowlisting known behavior | Reduces false positives — e.g., health check process is expected |
| Priority-based routing | Critical → PagerDuty immediately; Warning → Slack daily digest |

## Usage

```bash
# Deploy Falco + Falcosidekick
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  -f k8s/falco-values.yaml

# Apply custom rules
kubectl create configmap falco-custom-rules \
  --from-file=rules/custom-rules.yaml \
  -n falco

# Simulate a detection (test in non-production)
kubectl exec -it some-pod -- bash    # triggers shell-in-container rule

# Check Falco logs
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50

# View Prometheus metrics
curl -s http://falcosidekick:2802/metrics | grep falco_events
```

## Production Considerations

- **Tune before enforce** — run in alert-only mode for 2 weeks to baseline noise before responding
- **Allowlist init containers** — many init containers legitimately write files; exclude them
- **Falco Talon** — automated response: `kubectl delete pod` when cryptominer is detected
- **Rule versioning** — store custom rules in Git, deploy via ConfigMap; review changes in PR

## Success Metrics

- Detection latency: < 2 seconds from syscall to Slack alert
- False positive rate: < 2 alerts/hour that require no action
- Rule coverage: 100% of MITRE ATT&CK container techniques have a detection rule
