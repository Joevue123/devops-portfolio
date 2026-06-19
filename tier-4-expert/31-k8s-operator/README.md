# 31 — Custom Kubernetes Operator

Build a production-grade Kubernetes operator in Go using controller-runtime. The operator manages a `WebApp` custom resource that automatically provisions a Deployment, Service, HPA, and Ingress — with full status reporting and safe deletion via finalizers.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Developer                                                  │
│  kubectl apply -f webapp.yaml (WebApp CR)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────┐
│  API Server                      │
│  WebApp CRD (webapp.example.com) │
└──────────────────────┬───────────┘
                       │ watch
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  WebApp Operator (controller-runtime)                        │
│                                                              │
│  Reconcile Loop:                                             │
│  1. Fetch WebApp CR                                          │
│  2. Add finalizer (prevent orphaned resources)               │
│  3. Create/update Deployment (image, replicas, resources)    │
│  4. Create/update Service (ClusterIP)                        │
│  5. Create/update Ingress (hostname, TLS)                    │
│  6. Create/update HPA (CPU target)                           │
│  7. Update WebApp.Status (conditions, endpoint, replicas)    │
│  8. On deletion: remove owned resources, remove finalizer    │
│                                                              │
│  Leader election → only one replica active                   │
│  Exponential backoff on transient errors                     │
└──────────────────────────────────────────────────────────────┘
                       │ owns
           ┌───────────┼───────────────┐
           ▼           ▼               ▼
     Deployment    Service           Ingress
     (+ HPA)      ClusterIP         (hostname)
```

## Problem Statement

Every microservice team writes the same boilerplate Kubernetes manifests. An operator codifies platform standards into a self-service CRD — developers declare `image`, `replicas`, and `hostname`; the operator handles the rest with consistent security, resource, and networking defaults.

## Key Files

```
api/v1alpha1/webapp_types.go      — CRD Go types (spec + status)
controllers/webapp_controller.go  — reconcile loop with finalizer
config/crd/webapp.yaml            — generated CRD manifest
main.go                           — operator entrypoint with leader election
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| controller-runtime over client-go directly | Handles cache, informers, event queuing, rate limiting |
| Finalizer for cleanup | Without it, deleting WebApp leaves orphaned Deployments |
| OwnerReference on child resources | Garbage collection is automatic when WebApp is deleted |
| Status conditions (metav1.Condition) | Standard pattern — integrates with kubectl wait, ArgoCD health checks |
| Leader election | Multiple operator replicas for HA, only one reconciles |

## Usage

```bash
# Install CRD
kubectl apply -f config/crd/webapp.yaml

# Deploy operator
kubectl apply -k config/

# Create a WebApp
kubectl apply -f - <<EOF
apiVersion: webapp.example.com/v1alpha1
kind: WebApp
metadata:
  name: my-api
  namespace: production
spec:
  image: myrepo/api:v1.2.3
  replicas: 3
  resources:
    requests: { cpu: "100m", memory: "128Mi" }
    limits:   { cpu: "500m", memory: "256Mi" }
  hostname: api.example.com
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUPercent: 70
EOF

# Check status
kubectl get webapp my-api -o yaml
# .status.conditions[Ready] = True
# .status.endpoint = https://api.example.com
# .status.readyReplicas = 3
```

## Production Considerations

- **Validation webhook** — reject invalid specs at admission time, not reconcile time
- **Conversion webhook** — allows API versioning (v1alpha1 → v1beta1) without breaking existing CRs
- **RBAC** — operator ServiceAccount gets least-privilege ClusterRole
- **Metrics** — expose `controller_runtime_reconcile_total` and `controller_runtime_reconcile_errors_total`
- **Rate limiting** — default workqueue rate limiter prevents thundering herd during cluster recovery
- **Fuzz testing** — test with malformed CRs using `go-fuzz` against the reconcile function

## Success Metrics

- Time-to-deploy for a new service: < 2 minutes (vs 30+ min writing manifests)
- Reconcile loop p99 latency < 100ms
- Zero orphaned resources after 1000 CR deletion events
