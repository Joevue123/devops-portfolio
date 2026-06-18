# 10 — Kubernetes Application Deployment

**Tier:** Foundational | **Skills:** Kubernetes, Deployments, HPA, Ingress, ConfigMap, Secrets, resource limits

## Problem Statement

Deploying to Kubernetes with just a `Deployment` and `Service` is a start, but production requires autoscaling, proper resource management, ingress routing, and graceful pod lifecycle. This project wires all those pieces together for a real-world Node.js API deployment.

## Architecture

```
External Traffic
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│  Ingress (nginx-ingress-controller)                         │
│    api.example.com/v1/*  → api-service                      │
│    TLS termination (cert-manager / Let's Encrypt)           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Service (ClusterIP: api-service)                           │
│    selector: app=api                                        │
│    port: 80 → targetPort: 3000                              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Deployment (api)                                           │
│  replicas: 3  (min) ... 10 (max via HPA)                    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Pod Spec                                           │    │
│  │                                                     │    │
│  │  containers:                                        │    │
│  │    - name: api                                      │    │
│  │      image: myapp:v1.2.3                            │    │
│  │      resources:                                     │    │
│  │        requests: cpu=100m memory=128Mi              │    │
│  │        limits:   cpu=500m memory=512Mi              │    │
│  │      readinessProbe: GET /health (5s interval)      │    │
│  │      livenessProbe:  GET /health (30s interval)     │    │
│  │      envFrom:                                       │    │
│  │        - configMapRef: api-config                   │    │
│  │        - secretRef:    api-secrets                  │    │
│  │                                                     │    │
│  │  strategy:                                          │    │
│  │    type: RollingUpdate                              │    │
│  │    maxUnavailable: 0    ← zero-downtime deploy      │    │
│  │    maxSurge: 1                                      │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  HorizontalPodAutoscaler                                    │
│    minReplicas: 3   maxReplicas: 10                         │
│    metrics:                                                 │
│      CPU: target 70% utilization                            │
│      Custom: requests_per_second > 1000 → scale up          │
└─────────────────────────────────────────────────────────────┘

Supporting Resources:
  ConfigMap: api-config    ← LOG_LEVEL, DB_HOST, REDIS_HOST
  Secret: api-secrets      ← DB_PASSWORD, API_KEY (base64)
  PodDisruptionBudget:     ← minAvailable: 2 (safe node drains)
  NetworkPolicy:           ← api pods only accept traffic from ingress
```

## Usage

```bash
# Apply all manifests
kubectl apply -k ./k8s/

# Watch rollout
kubectl rollout status deployment/api -n production

# Check pod health
kubectl get pods -n production -l app=api -w

# View HPA status
kubectl get hpa api-hpa -n production

# Trigger manual scaling
kubectl scale deployment api --replicas=5 -n production

# Rolling update (bump image tag)
kubectl set image deployment/api api=myapp:v1.2.4 -n production

# Rollback if something goes wrong
kubectl rollout undo deployment/api -n production

# View resource usage
kubectl top pods -n production -l app=api
```

## Manifest Structure

```
k8s/
├── kustomization.yaml        ← Kustomize root (envs via overlays)
├── base/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── configmap.yaml
│   ├── secret.yaml           ← Sealed with Sealed Secrets / SOPS
│   ├── pdb.yaml              ← PodDisruptionBudget
│   └── networkpolicy.yaml
└── overlays/
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml   ← replicas: 1 in staging
    └── production/
        ├── kustomization.yaml
        └── patch-resources.yaml  ← larger resource limits
```

## Key Decisions

- **`maxUnavailable: 0`** — zero-downtime deployments; always maintain full capacity during rollout
- **`readinessProbe` separate from `livenessProbe`** — pod removed from LB while still running (prevents hard crash loops)
- **PodDisruptionBudget** — ensures at least 2 replicas stay up during node drain/upgrades
- **Kustomize overlays** — same base manifests for staging and production, environment-specific patches

## Production Considerations

- Store Secrets in Vault or use External Secrets Operator (not Kubernetes Secrets for sensitive creds)
- Add `topologySpreadConstraints` to spread pods across AZs for resilience
- Enable VPA (Vertical Pod Autoscaler) in recommendation mode to right-size resource requests
- Use `kubectl diff` in CI to preview manifest changes before apply

## Metrics for Success

- Zero-downtime deployments: 100% of rolling updates
- Time to scale from 3 → 10 pods under load < 90 seconds
- Pod restart rate < 1 per day in steady state
