# 05 — GitHub Actions CI Pipeline

**Tier:** Foundational | **Skills:** GitHub Actions, matrix builds, caching, OIDC, security scanning

## Problem Statement

A CI pipeline that just runs tests isn't enough. This pipeline enforces code quality, security posture, and build integrity — with matrix builds across Node versions, dependency caching for speed, and OIDC-based cloud auth (no stored credentials).

## Architecture

```
Pull Request / Push to main
            │
            ▼
┌───────────────────────────────────────────────────────┐
│                   GitHub Actions                       │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Job: lint-and-type-check (runs first, fastest) │  │
│  │    eslint, prettier check, tsc --noEmit         │  │
│  └─────────────────────┬───────────────────────────┘  │
│                        │ on success                    │
│            ┌───────────┴───────────┐                  │
│            │                       │                  │
│  ┌─────────▼──────────┐  ┌────────▼───────────────┐  │
│  │  Job: test         │  │  Job: security-scan     │  │
│  │  matrix:           │  │    trivy (container)    │  │
│  │    node: [18,20,22]│  │    gitleaks (secrets)   │  │
│  │    os: [ubuntu,    │  │    npm audit            │  │
│  │        windows]    │  └────────────────────────┘  │
│  │  jest + coverage   │                               │
│  └─────────┬──────────┘                              │
│            │ on success (main branch only)            │
│            ▼                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Job: build-and-push                            │  │
│  │    docker buildx (multi-arch: amd64, arm64)     │  │
│  │    OIDC → ECR (no stored AWS credentials)       │  │
│  │    image: tagged with git SHA + semver          │  │
│  └─────────────────────┬───────────────────────────┘  │
│                        │                              │
│            ┌───────────┴───────────┐                  │
│            │                       │                  │
│  ┌─────────▼──────────┐  ┌────────▼───────────────┐  │
│  │  Job: deploy-staging│  │  Job: notify           │  │
│  │    ArgoCD sync      │  │    Slack webhook       │  │
│  │    smoke tests      │  │    PR comment          │  │
│  └────────────────────┘  └────────────────────────┘  │
└───────────────────────────────────────────────────────┘

Cache strategy:
  ~/.npm          → actions/cache (keyed on package-lock.json)
  Docker layers   → actions/cache + buildx inline cache
```

## Key Decisions

- **OIDC for AWS auth** — no long-lived credentials stored in GitHub Secrets; AWS validates the GitHub JWT
- **Matrix builds** — catch Node.js version regressions before users do
- **Lint runs first** — cheapest check acts as a gate; saves compute on obviously broken PRs
- **Multi-arch Docker build** — ARM64 support for cost savings on AWS Graviton

## Production Considerations

- Add SLSA provenance generation (`actions/attest-build-provenance`) for supply chain security
- Gate production deploy behind manual approval (`environment: production`)
- Set `permissions: contents: read` at workflow level; grant only what each job needs
- Cache Docker layers in a registry (not just GHA cache) for cross-PR reuse

## Metrics for Success

- Pipeline p50 runtime < 4 minutes
- Cache hit rate > 85% on dependency restore
- Zero secrets in workflow logs or artifacts
