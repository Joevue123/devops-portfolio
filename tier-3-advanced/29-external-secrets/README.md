# 29 — External Secrets Operator

**Tier:** Advanced | **Skills:** External Secrets Operator, AWS Secrets Manager, Vault, secret rotation

## Problem Statement

Vault agent sidecars work per-pod, but cluster-wide secrets (TLS certs, shared API keys) need a different pattern. External Secrets Operator syncs secrets from AWS Secrets Manager, Vault, or GCP Secret Manager into Kubernetes Secrets on a schedule — and rotates them automatically when the source changes.

## Architecture

```
Secret Sources (external)
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ AWS Secrets  │  │ HashiCorp    │  │ GCP Secret   │
│ Manager      │  │ Vault        │  │ Manager      │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └─────────────────┼─────────────────┘
                         │ pull every 1h (or on change)
                         ▼
┌────────────────────────────────────────────────────────────────┐
│  External Secrets Operator (ESO)                               │
│                                                                │
│  SecretStore / ClusterSecretStore                              │
│    ← defines HOW to connect (IRSA, Vault token, etc.)         │
│                                                                │
│  ExternalSecret                                                │
│    ← defines WHAT to sync and WHERE to put it                 │
│                                                                │
│  ESO reconcile loop:                                           │
│    1. Read secret from external store                          │
│    2. Create/update K8s Secret                                 │
│    3. Set refreshInterval timer                                │
│    4. On next tick, re-read and update if changed             │
│       (automatic rotation — no manual kubectl patch)           │
└──────────────────────────────────┬─────────────────────────────┘
                                   │ creates/updates
                                   ▼
┌────────────────────────────────────────────────────────────────┐
│  Kubernetes Secrets (namespace-scoped)                         │
│    api-secrets       ← synced from AWS SM: /prod/api/*         │
│    db-credentials    ← synced from Vault: database/creds/api   │
│    tls-wildcard      ← synced from Vault: pki/issue/wildcard   │
│                                                                │
│  Consumed by Pods via:                                         │
│    envFrom: secretRef  OR  volumeMount                         │
└────────────────────────────────────────────────────────────────┘

When AWS SM secret rotates (Lambda rotation function):
  ESO detects change on next poll → updates K8s Secret
  Pods restart (via Reloader) → pick up new credentials
  Total rotation time: < 1 hour, zero human intervention
```

## Usage

```bash
# Install ESO
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Apply SecretStores and ExternalSecrets
kubectl apply -f k8s/

# Check sync status
kubectl get externalsecret -n production
kubectl describe externalsecret api-secrets -n production

# Force immediate sync
kubectl annotate externalsecret api-secrets \
  force-sync=$(date +%s) -n production --overwrite

# Watch the synced K8s secret
kubectl get secret api-secrets -n production -o yaml
```

## Key Decisions

- **`ClusterSecretStore` for shared infrastructure secrets** — one store definition, used by any namespace
- **`refreshInterval: 1h`** — balance between rotation freshness and API rate limits
- **Stakater Reloader alongside ESO** — watches Secret changes and rolling-restarts Deployments automatically
- **`creationPolicy: Owner`** — ESO owns the K8s Secret; if ExternalSecret is deleted, Secret is too

## Production Considerations

- Set `deletionPolicy: Retain` for critical secrets — ESO deletion shouldn't take down production
- Use `PushSecret` (reverse sync) to propagate secrets from K8s to external stores for cross-cluster sharing
- Monitor `externalsecret_status_condition` metric — alert when sync fails (secret provider outage)
- Combine with AWS SM automatic rotation (30-day) for fully automated credential lifecycle

## Metrics for Success

- Zero manually managed K8s Secrets (all synced from external stores)
- Secret rotation reflected in pods within 1 hour of source change
- ESO sync failure rate 0% over 30-day period
