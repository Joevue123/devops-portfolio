# 47 — GitOps Fleet Management at Scale

Manage 20+ Kubernetes clusters from a single ArgoCD control plane using ApplicationSets. Each cluster has the same base platform (cert-manager, ingress, monitoring) plus environment-specific apps. Cluster drift is detected within 1 minute.

## Architecture

```
Management Cluster (ArgoCD)
├── ArgoCD ApplicationSet — platform-components
│   └── generator: clusters with label env in [staging, production]
│       → creates one Application per cluster
│       → deploys: cert-manager, ingress-nginx, external-secrets, falco
│
├── ArgoCD ApplicationSet — team-apps
│   └── generator: git (reads apps/ directory per cluster)
│       → creates Applications for each team's apps per cluster
│
├── ArgoCD ApplicationSet — cluster-addons
│   └── generator: matrix (clusters × addons)
│       → ensures consistent addons across fleet
│
Cluster Inventory (Git):
clusters/
├── production-us-east-1/
│   ├── metadata.yaml       ← cluster labels, region, tier
│   └── apps/               ← team apps for this cluster
├── production-eu-west-1/
├── staging-us-east-1/
└── ...

Policy:
├── All clusters must have cert-manager v1.14.x
├── All clusters must have Falco with latest custom rules
└── Drift alert: Slack notification within 2 minutes of sync failure
```

## Problem Statement

With 5+ clusters, manual `kubectl apply` across all clusters is error-prone and slow. One ArgoCD ApplicationSet can enforce platform standards on 50 clusters simultaneously — if a cluster drifts, ArgoCD detects and corrects it automatically.

## Key Files

```
applicationsets/platform-components.yaml  — deploy platform to every cluster
applicationsets/team-apps.yaml            — deploy team apps from Git matrix
applicationsets/cluster-addons.yaml       — addon matrix (clusters × addons)
scripts/register-cluster.sh               — add new cluster to ArgoCD fleet
scripts/fleet-status.sh                   — health summary across all clusters
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| ApplicationSet over manual Applications | One change propagates to all clusters automatically |
| Cluster generator from ArgoCD secrets | ArgoCD already has cluster kubeconfigs — no separate inventory |
| Git directory generator for team apps | Each cluster directory is self-describing — no central registry |
| Matrix generator for addons | Avoids copy-paste — addon × cluster combinations auto-generated |
| selfHeal: true everywhere | Drift is auto-corrected within 1 reconcile cycle |

## Usage

```bash
# Add a new cluster to the fleet
./scripts/register-cluster.sh \
  --name production-ap-southeast-1 \
  --server https://k8s.example.com \
  --kubeconfig ~/.kube/production-ap.kubeconfig \
  --labels "env=production,region=ap-southeast-1"

# Once registered, ArgoCD automatically deploys all platform components
# and apps matching the cluster's labels — no further manual steps

# Check fleet health
./scripts/fleet-status.sh

# Force sync all production clusters
argocd app list -l env=production -o name | \
  xargs -I{} argocd app sync {} --async

# Check for drift across fleet
argocd app list --output json | \
  jq '.[] | select(.status.sync.status != "Synced") | {name: .metadata.name, cluster: .spec.destination.server}'
```

## Production Considerations

- **ArgoCD HA** — multi-replica ArgoCD in management cluster; manages all clusters from one pane
- **Secret management** — cluster kubeconfigs in Vault, synced to ArgoCD via ESO
- **Rollout strategy** — use wave annotations to upgrade staging clusters before production
- **Notification controller** — Slack alert when any cluster has Degraded or OutOfSync apps

## Success Metrics

- Drift detection: < 2 minutes from Git push to sync start on all clusters
- Fleet coverage: 100% of clusters managed via ApplicationSets (zero manual kubectl)
- Platform consistency: all clusters running within 1 minor version of each other
