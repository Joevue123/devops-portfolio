# 14 — Vault Secrets Management

**Tier:** Intermediate | **Skills:** HashiCorp Vault, dynamic secrets, K8s auth, sidecar injection

## Problem Statement

Hardcoded secrets in environment variables and Kubernetes Secrets (base64 ≠ encrypted) are a security liability. Vault centralizes secrets with fine-grained policies, automatic rotation, and audit logging — apps get short-lived credentials they can't leak.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Developer / CI Pipeline                                     │
│    writes secret once:  vault kv put secret/api db_pass=xxx  │
└──────────────────────────────────┬───────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                    HashiCorp Vault                           │
│                                                              │
│  Auth Methods:                                               │
│    Kubernetes auth  ← pods authenticate via ServiceAccount   │
│    GitHub auth      ← devs authenticate via GitHub token     │
│    AppRole          ← CI/CD pipelines                        │
│                                                              │
│  Secret Engines:                                             │
│    KV v2            ← static secrets with versioning         │
│    Database         ← dynamic PostgreSQL credentials         │
│      └─ Vault connects to DB, creates short-lived user       │
│         (TTL: 1h), revokes on expiry — no shared passwords   │
│    PKI              ← issues short-lived TLS certificates     │
│    AWS              ← dynamic IAM credentials                │
│                                                              │
│  Policies:                                                   │
│    api-policy      ← read secret/data/api/*                  │
│    readonly        ← read-only to specific paths             │
│    admin           ← full access (humans only)               │
│                                                              │
│  Audit Log → file / syslog (who read what, when)            │
└──────────────────────────────────┬───────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
         Agent Sidecar                  External Secrets Op.
         (K8s pod)                      (K8s cluster-wide)
         ┌──────────────────┐           ┌──────────────────┐
         │  vault-agent     │           │  ExternalSecret  │
         │  init container  │           │  CRD syncs       │
         │  renders secrets │           │  Vault → K8s     │
         │  to /vault/      │           │  Secret on       │
         │  secrets/        │           │  schedule        │
         └──────────────────┘           └──────────────────┘
```

## Usage

```bash
# Start Vault in dev mode (local testing)
docker compose up -d

# Initialize and unseal (production — store unseal keys safely)
vault operator init -key-shares=5 -key-threshold=3
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>

# Enable K8s auth method
./scripts/init-vault.sh

# Write a static secret
vault kv put secret/api/production db_password="s3cr3t" api_key="xyz"

# Read it back
vault kv get secret/api/production

# Get a dynamic PostgreSQL credential (expires in 1 hour)
vault read database/creds/api-role

# Check audit log
vault audit list
```

## Key Decisions

- **Dynamic DB credentials** — each app instance gets a unique DB user; breach = revoke one user, not rotate shared password
- **Agent sidecar injection** — secrets rendered to tmpfs volume, never stored in etcd as K8s Secrets
- **Short TTLs (1h for DB, 24h for KV leases)** — blast radius of a leaked credential is time-bounded
- **Policies as code** — HCL policy files in Git, applied via CI; humans never manually `vault policy write` in production

## Production Considerations

- Run Vault in HA mode with Raft integrated storage (3-node cluster, no external Consul needed)
- Enable auto-unseal with AWS KMS / GCP CKMS — manual unseal is operationally risky
- Back up Vault snapshots to S3 daily: `vault operator raft snapshot save backup.snap`
- Set up Vault Agent caching to reduce load from many pods hitting Vault simultaneously

## Metrics for Success

- Zero plaintext secrets in Kubernetes Secrets or environment variables
- 100% of DB connections using dynamic credentials
- Secret access fully auditable in Vault audit log
