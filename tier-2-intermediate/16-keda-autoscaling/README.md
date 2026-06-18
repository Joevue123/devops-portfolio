# 16 — KEDA Event-Driven Autoscaling

**Tier:** Intermediate | **Skills:** KEDA, Kubernetes, SQS, HTTP scaling, custom metrics

## Problem Statement

CPU-based HPA is the wrong signal for many workloads — a queue worker should scale on queue depth, not CPU. KEDA extends Kubernetes autoscaling to 50+ event sources: SQS queue depth, Kafka lag, HTTP RPS, Prometheus metrics, cron schedules, and more.

## Architecture

```
Event Sources
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  AWS SQS     │  │  HTTP        │  │  Prometheus  │
│  Queue       │  │  Requests    │  │  Metric      │
│  depth: 500  │  │  RPS: 2000   │  │  custom_jobs │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └─────────────────┼─────────────────┘
                         │ polls every 30s
                         ▼
┌────────────────────────────────────────────────────┐
│              KEDA (keda-operator)                  │
│                                                    │
│  ScaledObject: worker                              │
│    scaleTargetRef: Deployment/worker               │
│    minReplicaCount: 0   ← scale to zero when idle  │
│    maxReplicaCount: 50                             │
│    triggers:                                       │
│      - type: aws-sqs-queue                         │
│        queueLength: 10  ← 1 pod per 10 messages   │
│                                                    │
│  Translates to → HPA with external metrics        │
└───────────────────────────┬────────────────────────┘
                            │ adjusts replicas
                            ▼
┌────────────────────────────────────────────────────┐
│              Deployment: worker                    │
│                                                    │
│  Queue empty:    0 pods  (scale to zero = $0)      │
│  10 messages:    1 pod                             │
│  100 messages:   10 pods                           │
│  500 messages:   50 pods (maxReplicaCount)         │
│                                                    │
│  Cool-down: 5 minutes before scaling down          │
│  (prevents thrashing on bursty queues)             │
└────────────────────────────────────────────────────┘
```

## Usage

```bash
# Install KEDA
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda -n keda --create-namespace

# Apply ScaledObjects
kubectl apply -f k8s/

# Watch scaling in real-time
kubectl get hpa -n production -w

# Simulate SQS load
./scripts/send-sqs-messages.sh 100

# Check KEDA operator logs
kubectl logs -n keda -l app=keda-operator -f
```

## Key Decisions

- **`minReplicaCount: 0`** — scales to zero when queue is empty; eliminates idle compute cost
- **`cooldownPeriod: 300s`** — 5-minute scale-down delay prevents thrashing on bursty workloads
- **`TriggerAuthentication` with IRSA** — KEDA accesses SQS via pod IAM role, no stored AWS keys
- **HTTP scaler via `http-add-on`** — scales API pods on active HTTP connections, not just CPU

## Production Considerations

- Test scale-to-zero carefully — cold start latency matters for latency-sensitive workloads
- Use `ScaledJob` instead of `ScaledObject` for batch workloads (one pod per message, run-to-completion)
- Monitor KEDA metrics endpoint for scaler errors (a failing scaler silently stops scaling)
- Combine KEDA with Karpenter (node autoscaler) for full cluster elasticity

## Metrics for Success

- Queue processing lag < 30 seconds at any message volume
- Zero idle worker pods when queue is empty (cost saving)
- Scale-out time from 0 → 10 pods < 60 seconds
