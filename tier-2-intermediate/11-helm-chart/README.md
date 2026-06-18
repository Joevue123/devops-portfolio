# 11 — Helm Chart — Microservice Packaging

**Tier:** Intermediate | **Skills:** Helm, Kubernetes, templating, values management

## Problem Statement

Copying raw YAML manifests between environments leads to drift and errors. Helm packages a microservice into a versioned, configurable chart — one source of truth that deploys consistently to dev, staging, and production with environment-specific overrides.

## Architecture

```
Chart Structure
┌─────────────────────────────────────────────────────────────┐
│  myapp/                                                     │
│  ├── Chart.yaml          ← name, version, appVersion        │
│  ├── values.yaml         ← defaults (safe for dev)          │
│  ├── values-staging.yaml ← staging overrides                │
│  ├── values-prod.yaml    ← production overrides             │
│  └── templates/                                             │
│      ├── _helpers.tpl    ← reusable name/label macros       │
│      ├── deployment.yaml ← uses {{ .Values.* }}             │
│      ├── service.yaml                                       │
│      ├── ingress.yaml    ← conditionally rendered           │
│      ├── hpa.yaml        ← conditionally rendered           │
│      ├── configmap.yaml                                     │
│      ├── secret.yaml     ← base64-encoded via helpers       │
│      ├── serviceaccount.yaml                                │
│      └── NOTES.txt       ← post-install instructions        │
└─────────────────────────────────────────────────────────────┘

Deployment Flow:
  helm install myapp ./myapp -f values-prod.yaml -n production

  values.yaml          ← base defaults
       +
  values-prod.yaml     ← production overrides
       =
  Rendered manifests   ← kubectl apply'd by Helm
```

## Usage

```bash
# Lint the chart
helm lint ./myapp

# Dry-run — preview rendered manifests
helm template myapp ./myapp -f values-prod.yaml

# Install
helm install myapp ./myapp -f values-prod.yaml -n production --create-namespace

# Upgrade (e.g. new image tag)
helm upgrade myapp ./myapp -f values-prod.yaml -n production \
  --set image.tag=v1.2.3 --atomic --timeout 5m

# Rollback to previous release
helm rollback myapp -n production

# Diff before upgrade (requires helm-diff plugin)
helm diff upgrade myapp ./myapp -f values-prod.yaml -n production
```

## Key Decisions

- **`_helpers.tpl` for all labels** — consistent `app.kubernetes.io/*` labels across every resource
- **`--atomic` on upgrade** — auto-rollback if any resource fails to become healthy
- **Conditional HPA and Ingress** — disabled in dev with `hpa.enabled: false` to save resources
- **No secrets in `values.yaml`** — secrets injected at deploy time via `--set` or external-secrets

## Production Considerations

- Publish chart to a Helm registry (OCI via ECR, or ChartMuseum) for versioned releases
- Use `helm secrets` plugin with SOPS to encrypt sensitive values files
- Add chart tests (`templates/tests/`) that `helm test` runs post-install
- Pin `Chart.yaml` `dependencies` versions to avoid surprise upstream changes

## Metrics for Success

- `helm lint` passes with 0 warnings
- `helm template` diff between environments shows only intentional differences
- Rollback time < 60 seconds on failed upgrade
