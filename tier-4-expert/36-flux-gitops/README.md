# 36 — Flux v2 GitOps Multi-Environment

Flux v2 watches a Git repository and reconciles cluster state. Multi-environment promotion flows from staging to production via pull request. Image automation detects new container image tags and opens a PR automatically.

## Architecture

```
Git Repository (gitops-config)
├── clusters/
│   ├── staging/
│   │   └── flux-system/     ← Flux bootstrapped here
│   └── production/
│       └── flux-system/     ← Flux bootstrapped here
├── infrastructure/
│   ├── base/                ← shared: cert-manager, ingress, monitoring
│   ├── staging/             ← overlay: staging-specific patches
│   └── production/          ← overlay: production-specific patches
└── apps/
    ├── base/                ← HelmRelease, Kustomization definitions
    ├── staging/             ← staging values (replicas: 1, debug: true)
    └── production/          ← production values (replicas: 3)

                 ┌────────────────────────┐
                 │ Flux GitRepository CR  │
                 │ polls Git every 1min   │
                 └───────────┬────────────┘
                             │ reconcile
                 ┌───────────┼─────────────────┐
                 ▼           ▼                 ▼
          Kustomization  HelmRelease    ImagePolicy
          (manifests)    (Helm charts)  (semver filter)
                                             │
                                    ImageUpdateAutomation
                                    (opens PR with new tag)
```

## Problem Statement

ArgoCD is great but some teams prefer Flux's Git-push model and its native image automation. This project shows how to build a complete GitOps workflow with automated image tag promotion.

## Key Files

```
clusters/production/flux-system/gotk-sync.yaml  — Flux bootstrap sync
apps/base/api-helmrelease.yaml                  — HelmRelease definition
apps/production/kustomization.yaml              — production-specific patches
image-automation/image-policy.yaml              — semver filter for images
image-automation/image-update-automation.yaml   — auto-PR on new image tag
scripts/flux-bootstrap.sh                       — cluster bootstrap script
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Flux v2 over v1 | Multi-tenancy, better multi-cluster support, native OCI |
| HelmRelease over raw manifests | Helm chart lifecycle (upgrade, rollback) managed by Flux |
| Image automation opens PRs (not direct push) | Review step before promotion to production |
| Separate cluster/ per environment | Each cluster's Flux reconciles its own path; no shared state |
| Semver image policy | `>=1.0.0 <2.0.0` filter prevents accidental major version promotion |

## Usage

```bash
# Bootstrap staging cluster
./scripts/flux-bootstrap.sh staging

# Bootstrap production cluster
./scripts/flux-bootstrap.sh production

# Check all Flux resources
flux get all -A

# Watch reconciliation
flux logs --follow --tail=20 --kind=HelmRelease --namespace=production

# Force immediate sync
flux reconcile source git flux-system
flux reconcile kustomization apps

# Promote staging → production
# After a new image tag is detected, image-update-automation opens a PR.
# Review and merge the PR; production Flux reconciles within 1 minute.
```

## Production Considerations

- **Flux notifications** — alert Slack on reconciliation failure via `Alert` + `Provider` CRs
- **Sealed Secrets or ESO** — Flux can't store Secrets in Git; use one of these for secret management
- **Read-only deploy keys** — Flux only needs pull access to the GitOps repo
- **Webhook receiver** — GitHub webhook → Flux webhook for instant reconcile on push (no 1min poll lag)

## Success Metrics

- Reconciliation lag: < 2 minutes from Git push to cluster state
- Image promotion: < 5 minutes from registry push to staging deploy
- Drift detected and auto-corrected within 1 reconciliation cycle (1 minute)
