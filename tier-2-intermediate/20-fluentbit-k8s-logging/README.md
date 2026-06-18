# 20 — Fluent Bit Kubernetes Log Pipeline

**Tier:** Intermediate | **Skills:** Fluent Bit, DaemonSet, log routing, Loki, multi-output

## Problem Statement

`kubectl logs` only shows one pod, can't query across pods, and loses logs when pods restart. Fluent Bit runs as a DaemonSet on every node, tails all container logs, parses and enriches them with K8s metadata, then ships them to Loki or Elasticsearch — zero application changes needed.

## Architecture

```
Kubernetes Nodes (DaemonSet — one Fluent Bit pod per node)
┌─────────────────────────────────────────────────────────────┐
│  Node                                                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  /var/log/containers/*.log  (symlinks to Docker     │    │
│  │                              or containerd logs)    │    │
│  └──────────────────────┬──────────────────────────────┘    │
│                         │ tail (inotify)                    │
│                         ▼                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Fluent Bit                                         │    │
│  │                                                     │    │
│  │  [INPUT]  tail                                      │    │
│  │    path: /var/log/containers/*.log                  │    │
│  │    parser: docker / cri                             │    │
│  │    db: /var/flb_kube.db  ← persists read offset     │    │
│  │                                                     │    │
│  │  [FILTER]  kubernetes                               │    │
│  │    ← enriches with: namespace, pod, container,      │    │
│  │      labels, annotations, node name                 │    │
│  │                                                     │    │
│  │  [FILTER]  grep                                     │    │
│  │    ← drops health check logs (/health, /metrics)    │    │
│  │                                                     │    │
│  │  [FILTER]  modify                                   │    │
│  │    ← normalizes field names across log formats      │    │
│  │                                                     │    │
│  │  [OUTPUT]  loki        ← app logs to Grafana Loki   │    │
│  │  [OUTPUT]  es          ← audit logs to Elasticsearch│    │
│  │  [OUTPUT]  cloudwatch  ← all logs to CloudWatch     │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘

Log query in Grafana (LogQL):
  {namespace="production", app="api"} |= "ERROR"
  | json | line_format "{{.message}}"
```

## Usage

```bash
# Install Fluent Bit via Helm
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit \
  -n logging --create-namespace \
  -f values.yaml

# Or apply raw manifests
kubectl apply -f k8s/

# Verify DaemonSet is running on all nodes
kubectl get daemonset fluent-bit -n logging
kubectl get pods -n logging -o wide

# Test log shipping — create a noisy pod
kubectl run log-test --image=busybox --restart=Never -- \
  sh -c 'while true; do echo "{\"level\":\"info\",\"msg\":\"test\"}"; sleep 1; done'

# Tail Fluent Bit output (debug)
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit -f

# Query logs in Loki via Grafana
# {namespace="default", pod="log-test"} | json
```

## Key Decisions

- **SQLite offset DB (`db` setting)** — survives Fluent Bit restarts without re-sending old logs
- **`Mem_Buf_Limit`** — caps memory usage per input; applies backpressure rather than OOM-killing the pod
- **Multi-output routing** — app logs → Loki (fast queries), audit logs → Elasticsearch (compliance), all → S3 (long-term)
- **Fluent Bit over Fluentd** — 10x lower memory usage; Fluentd only if complex Ruby plugins are needed

## Production Considerations

- Enable `storage.type filesystem` for Fluent Bit's buffer — survives node pressure better than memory buffers
- Set resource requests/limits: typical values are 50m CPU / 128Mi RAM per node
- Use `Exclude_Path` to skip high-volume logs from monitoring namespaces (kube-system, istio-system)
- Forward to two outputs in parallel for redundancy — Loki primary, S3 as archival backup

## Metrics for Success

- Log delivery lag < 5 seconds from write to Loki query
- Zero log loss on pod restart (SQLite offset DB)
- Fluent Bit pod memory < 128MB per node at steady state
