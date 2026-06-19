# 22 — Chaos Engineering with Litmus

**Tier:** Advanced | **Skills:** Chaos engineering, Litmus, resilience testing, game days

## Problem Statement

You don't know if your system is resilient until it breaks in production — usually at the worst time. Chaos engineering deliberately injects failures in controlled conditions, finds weaknesses before users do, and builds confidence that services recover correctly.

## Architecture

```
Chaos Control Plane (LitmusChaos)
┌────────────────────────────────────────────────────────────┐
│  ChaosCenter (web UI + API)                                │
│    └── Schedules ChaosEngine CRDs on target clusters       │
└─────────────────────────────┬──────────────────────────────┘
                              │ ChaosEngine CRD
                              ▼
Target Kubernetes Cluster
┌────────────────────────────────────────────────────────────┐
│                                                            │
│  Experiment: pod-delete                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ChaosAgent watches ChaosEngine                     │  │
│  │  Selects target pods by label (app=api)             │  │
│  │  Deletes 1 pod every 30s for 2 minutes              │  │
│  │  Observes: does K8s reschedule? Do requests fail?   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  Experiment: network-latency                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Injects 200ms latency on pod's network interface   │  │
│  │  via tc (traffic control) inside the container       │  │
│  │  Observes: do retries work? Does circuit break?      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  Experiment: node-drain                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Cordons + drains a random worker node               │  │
│  │  Observes: do PDBs work? Are pods rescheduled?       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  Steady-State Hypothesis (measured before + after):        │
│    ✓ API error rate < 1%                                   │
│    ✓ All pods Ready within 120s of fault injection         │
│    ✓ No data loss in DB (writes during chaos)              │
└────────────────────────────────────────────────────────────┘

Chaos Workflow Schedule:
  Staging: weekly automated game day
  Production: monthly, during low-traffic window
```

## Usage

```bash
# Install LitmusChaos
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.9.0.yaml

# Apply RBAC for chaos experiments
kubectl apply -f k8s/rbac.yaml

# Run pod-delete experiment
kubectl apply -f experiments/pod-delete.yaml

# Watch experiment progress
kubectl get chaosresult -n production -w
kubectl describe chaosresult api-pod-delete -n production

# Run the full game-day workflow
kubectl apply -f workflows/game-day.yaml

# Access ChaosCenter UI
kubectl port-forward svc/litmus-frontend-service 9091:9091 -n litmus
```

## Key Decisions

- **Steady-state hypothesis first** — define what "working" looks like *before* injecting chaos
- **Start with staging** — build confidence in experiments before targeting production
- **Observability prerequisite** — chaos without metrics is just breaking things; Prometheus must be running
- **Blast radius controls** — `podsAffectedPerc: 50` ensures max 50% of pods targeted at once

## Production Considerations

- Run chaos experiments in CI on staging after every major deploy ("chaos as code")
- Use GameDay runbooks — document what each experiment tests and what failure means
- Integrate with incident management: auto-create an incident ticket if steady state breaks
- Track "chaos score" over time to measure resilience improvement

## Metrics for Success

- 100% of critical failure modes have a corresponding chaos experiment
- System recovers to steady state within defined SLO after every experiment
- Zero unexpected production incidents from failure modes already tested in chaos
