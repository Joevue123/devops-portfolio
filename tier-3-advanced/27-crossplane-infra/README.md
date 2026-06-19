# 27 — Crossplane Infrastructure Composition

**Tier:** Advanced | **Skills:** Crossplane, platform engineering, Composite Resources, XRD

## Problem Statement

Developers shouldn't need to know Terraform or AWS IAM to provision a database. Crossplane lets platform engineers define opinionated `XPostgreSQLInstance` CRDs — developers `kubectl apply` an abstraction, Crossplane provisions real AWS/GCP resources and returns connection details as a K8s Secret.

## Architecture

```
Developer (self-service)                Platform Engineer
┌────────────────────┐                 ┌────────────────────────────┐
│  kubectl apply:    │                 │  Defines once:             │
│                    │                 │                            │
│  kind: AppDatabase │                 │  CompositeResourceDef      │
│  spec:             │                 │    (XRD) — the API schema  │
│    size: small     │                 │                            │
│    engine: postgres│                 │  Composition               │
│    team: payments  │                 │    maps XRD → real AWS     │
│                    │                 │    resources               │
└─────────┬──────────┘                 └────────────────────────────┘
          │
          ▼ Crossplane reconciles
┌──────────────────────────────────────────────────────────────────┐
│  Crossplane (running in-cluster)                                 │
│                                                                  │
│  Composition: AppDatabase → {                                    │
│    RDSInstance      (aws.upbound.io)                             │
│    SubnetGroup      (aws.upbound.io)                             │
│    SecurityGroup    (aws.upbound.io)                             │
│    IAMRole          (aws.upbound.io) ← for app to connect        │
│    ParameterGroup   (aws.upbound.io)                             │
│  }                                                               │
│                                                                  │
│  After provisioning:                                             │
│    Connection details written to K8s Secret: app-db-conn         │
│    Developer mounts the Secret — no AWS console access needed    │
└──────────────────────────────────────────────────────────────────┘

Developer gets:
  Secret/app-db-conn:
    host: mydb.xxxx.rds.amazonaws.com
    port: 5432
    username: appuser
    password: <generated>
    database: appdb
```

## Usage

```bash
# Install Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane crossplane-stable/crossplane \
  -n crossplane-system --create-namespace

# Install AWS provider
kubectl apply -f providers/aws-provider.yaml
kubectl wait provider/upbound-provider-aws --for=condition=Healthy --timeout=300s

# Configure AWS credentials (via IRSA in production)
kubectl apply -f providers/provider-config.yaml

# Apply platform team definitions
kubectl apply -f xrds/
kubectl apply -f compositions/

# Developer self-service: provision a database
kubectl apply -f claims/app-database.yaml

# Watch provisioning
kubectl get appdatabase -w
kubectl describe appdatabase my-app-db

# Get connection details
kubectl get secret app-db-conn -o jsonpath='{.data.host}' | base64 -d
```

## Key Decisions

- **XRD abstracts cloud details** — developer says `size: small`, Crossplane picks `db.t3.micro`; no cloud knowledge needed
- **Composition patches** — transform claim fields to provider fields via CEL expressions and transforms
- **Connection Secret auto-generated** — platform controls the format; app consumes a consistent Secret shape
- **`publishConnectionDetailsTo` with ESO** — connection details go to Vault, not just K8s Secrets

## Production Considerations

- Use Upbound's managed Crossplane (MCP) to avoid running the control plane yourself
- Version Compositions — breaking changes to XRDs require migration paths like CRD versioning
- Add `readinessCheck` to Compositions so the claim stays NotReady until all resources are healthy
- Implement quota enforcement via XRD validation (e.g. max 2 databases per namespace)

## Metrics for Success

- Developer self-service provisioning time < 5 minutes (no platform team ticket)
- Zero AWS console access needed by developers for standard infrastructure
- 100% of cloud resources traceable to a K8s Composition claim
