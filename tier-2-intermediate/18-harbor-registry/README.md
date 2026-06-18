# 18 — Harbor Container Registry

**Tier:** Intermediate | **Skills:** Harbor, container security, image scanning, replication, RBAC

## Problem Statement

Pushing to Docker Hub means public images, rate limits, and no control over who pulls what. Harbor is a self-hosted OCI registry with built-in vulnerability scanning, image signing, replication, and project-level RBAC — it's what large-scale internal platforms run.

## Architecture

```
Developer Workstation / CI Pipeline
  docker push harbor.example.com/myproject/myapp:v1.2.3
         │
         ▼ HTTPS + auth
┌─────────────────────────────────────────────────────────────┐
│                    Harbor                                   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Projects (RBAC boundary)                           │   │
│  │    myproject/  ← team namespace                     │   │
│  │      Public: false                                  │   │
│  │      Members: dev-team (developer), ci-bot (robot)  │   │
│  │      Quota: 50GB storage                            │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Vulnerability Scanning (Trivy)                     │   │
│  │    on push: scan immediately                        │   │
│  │    policy: block pull if CRITICAL CVE found         │   │
│  │    schedule: rescan all images daily                │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Replication Rules                                  │   │
│  │    harbor → AWS ECR (production region)             │   │
│  │    harbor → harbor-dr (disaster recovery site)      │   │
│  │    trigger: on push, filter: tag=v*                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Retention Policy                                   │   │
│  │    keep last 10 tags per repo                       │   │
│  │    always keep: tags matching v[0-9]+.[0-9]+.[0-9]+ │   │
│  │    delete: untagged images after 7 days             │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  Storage backends: filesystem / S3 / Azure Blob / GCS      │
└─────────────────────────────────────────────────────────────┘
```

## Usage

```bash
# Start Harbor
./scripts/setup-harbor.sh   # generates certs, runs docker compose

# Login
docker login harbor.example.com -u admin

# Push an image
docker tag myapp:latest harbor.example.com/myproject/myapp:v1.0.0
docker push harbor.example.com/myproject/myapp:v1.0.0

# Create a robot account for CI
./scripts/create-robot-account.sh myproject ci-bot

# Scan an image via API
curl -u admin:Harbor12345 -X POST \
  "https://harbor.example.com/api/v2.0/projects/myproject/repositories/myapp/artifacts/v1.0.0/scan"

# Check scan results
curl -u admin:Harbor12345 \
  "https://harbor.example.com/api/v2.0/projects/myproject/repositories/myapp/artifacts/v1.0.0/additions/vulnerabilities"
```

## Key Decisions

- **Robot accounts for CI** — short-lived tokens per project, not shared admin credentials
- **Block pull on CRITICAL CVE** — enforced at registry level, not dependent on CI compliance
- **Replication to ECR** — Kubernetes clusters pull from ECR (low-latency, no Harbor dependency at deploy time)
- **Retention policy** — prevents unbounded storage growth from CI pushing every commit

## Production Considerations

- Store Harbor data on S3 (not local disk) for resilience and unlimited storage
- Enable TLS with a real cert (cert-manager) — Docker refuses insecure registries
- Set up LDAP/OIDC integration so engineers log in with SSO, not Harbor passwords
- Monitor `harbor_registry_storage_usage_bytes` to alert before storage quota is hit

## Metrics for Success

- Image scan results available < 2 minutes after push
- Zero CRITICAL vulnerabilities in production images
- Replication lag to ECR < 5 minutes after push
