# 34 — OpenTelemetry Unified Observability

Deploy the OpenTelemetry Collector as a DaemonSet and Gateway to ingest traces, metrics, and logs from all services. Auto-instrument Node.js and Python apps with zero code changes. Route signals to Jaeger (traces), Prometheus (metrics), and Loki (logs).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Application Pods                                                   │
│  ┌──────────────────────────────────────────────────┐              │
│  │  App Container     │  OTel Sidecar/Agent         │              │
│  │  (auto-instrumented│  (receives OTLP from app)   │              │
│  │  via InitContainer)│                             │              │
│  └──────────────────────────────────────────────────┘              │
│                              │ OTLP gRPC                           │
│                              ▼                                      │
│  ┌──────────────────────────────────────┐                          │
│  │  OTel Collector DaemonSet            │                          │
│  │  (node-level: host metrics, logs)    │                          │
│  └──────────────────┬───────────────────┘                          │
│                     │ OTLP                                          │
│                     ▼                                               │
│  ┌──────────────────────────────────────┐                          │
│  │  OTel Collector Gateway (Deployment) │                          │
│  │  Pipelines:                          │                          │
│  │  traces  → Jaeger / Tempo            │                          │
│  │  metrics → Prometheus remote_write   │                          │
│  │  logs    → Loki                      │                          │
│  └──────────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────────┘
```

## Problem Statement

Three separate agents (Jaeger agent, Prometheus exporter, Fluent Bit) per pod means 3x overhead, 3x configs, and signals that can't be correlated. OTel unifies collection with a single OTLP pipeline — trace IDs link to logs, logs link to metrics.

## Key Files

```
k8s/collector-daemonset.yaml    — node-level agent: hostmetrics + log collection
k8s/collector-gateway.yaml      — OTelCol gateway with routing pipeline
k8s/instrumentation.yaml        — auto-instrumentation CR (Node.js + Python)
k8s/collector-config.yaml       — ConfigMap with full pipeline configuration
docker/docker-compose.yml       — local dev stack (app + OTelCol + Jaeger + Prometheus)
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| DaemonSet agent + Gateway pattern | Agent stays close to data; gateway handles batching and retry |
| Auto-instrumentation via InitContainer | Zero code changes in application repos |
| OTLP over Zipkin/Jaeger wire format | OTLP is the native OTel format; no translation loss |
| Tail sampling at the gateway | Sample 100% of error/slow traces, 1% of successful traces |
| W3C TraceContext propagation | Standard header (`traceparent`) works across all languages |

## Usage

```bash
# Install OTel Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Deploy collector infrastructure
kubectl apply -f k8s/collector-config.yaml
kubectl apply -f k8s/collector-daemonset.yaml
kubectl apply -f k8s/collector-gateway.yaml

# Enable auto-instrumentation for a namespace
kubectl apply -f k8s/instrumentation.yaml

# Annotate a deployment to inject OTel agent
kubectl patch deployment my-api -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"true"}}}}}'

# Local dev
cd docker && docker compose up
# Open http://localhost:16686 for Jaeger UI
```

## Production Considerations

- **Tail sampling** — decide which traces to keep *after* seeing the full trace, not at ingestion
- **Resource detection** — auto-detect cloud provider, k8s node, pod metadata from environment
- **Backpressure** — collector queue size limits prevent OOM when backend is slow
- **Secret management** — backend endpoints/tokens in Secrets, not ConfigMaps

## Success Metrics

- Trace coverage: 100% of HTTP requests have a trace ID
- Log-trace correlation: 100% of error logs include `trace_id` field
- Collection overhead: < 2% CPU, < 50MB memory per node agent
