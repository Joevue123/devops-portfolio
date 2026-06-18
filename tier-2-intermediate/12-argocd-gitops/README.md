# 12 — ArgoCD GitOps Pipeline

**Tier:** Intermediate | **Skills:** ArgoCD, GitOps, App of Apps, sync waves, RBAC

## Problem Statement

Imperative `kubectl apply` deployments leave no audit trail and diverge from Git. ArgoCD makes Git the single source of truth — every change is a PR, every deploy is reproducible, and drift is detected and corrected automatically.

## Architecture

```
Git Repository (source of truth)
┌────────────────────────────────────────────────────────────┐
│  gitops-repo/                                              │
│  ├── argocd/                                               │
│  │   ├── projects/portfolio.yaml   ← AppProject (RBAC)     │
│  │   └── apps/                                             │
│  │       ├── root-app.yaml         ← App of Apps           │
│  │       ├── api.yaml                                      │
│  │       ├── monitoring.yaml                               │
│  │       └── ingress-nginx.yaml                            │
│  └── apps/                                                 │
│      ├── api/k8s/                  ← raw manifests or Helm │
│      └── monitoring/               ← Prometheus stack      │
└─────────────────────────────────────┬──────────────────────┘
                                      │ git pull (every 3m)
                                      ▼
┌────────────────────────────────────────────────────────────┐
│                  ArgoCD (in-cluster)                       │
│                                                            │
│  App of Apps (root-app)                                    │
│       │                                                    │
│       ├── AppProject: portfolio   ← limits source repos    │
│       │                              and dest namespaces   │
│       ├── Application: api        ← syncs apps/api/        │
│       ├── Application: monitoring ← syncs apps/monitoring/ │
│       └── Application: ingress    ← syncs infra/ingress/   │
│                                                            │
│  Sync Policy: automated                                    │
│    prune: true   ← removes resources deleted from Git      │
│    selfHeal: true ← reverts manual kubectl changes         │
└─────────────────────────────────┬──────────────────────────┘
                                  │ kubectl apply
                                  ▼
                         Kubernetes Cluster
```

## Usage

```bash
# Bootstrap ArgoCD into cluster
./scripts/bootstrap-argocd.sh

# Apply the root App of Apps — ArgoCD manages itself from here
kubectl apply -f argocd/apps/root-app.yaml -n argocd

# Watch sync status
argocd app list
argocd app get api --show-operation

# Manually trigger sync (normally automatic)
argocd app sync api

# Force hard refresh (bypass cache)
argocd app get api --hard-refresh

# View diff between live state and Git
argocd app diff api
```

## Key Decisions

- **App of Apps pattern** — one root Application deploys all other Applications; ArgoCD manages its own apps
- **`selfHeal: true`** — any manual `kubectl` change is reverted within 3 minutes; enforces GitOps discipline
- **AppProject RBAC** — restricts which repos and namespaces each team's apps can touch
- **Sync waves** — `argocd.argoproj.io/sync-wave: "-1"` deploys CRDs and namespaces before apps

## Production Considerations

- Use `argocd-image-updater` to auto-bump image tags in Git when a new image is pushed to registry
- Enable SSO (Dex + GitHub OAuth) — never leave ArgoCD on default admin password
- Store ArgoCD itself as an Application in the root app (fully self-managing GitOps)
- Use `ignoreDifferences` for fields mutated by controllers (e.g. `replicas` if using HPA)

## Metrics for Success

- Drift detection and self-heal time < 3 minutes
- All production changes traceable to a Git commit and PR
- Zero manual `kubectl apply` in production (enforced by RBAC)
