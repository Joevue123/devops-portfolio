# 03 — Docker Multi-Stage Build

**Tier:** Foundational | **Skills:** Docker, image optimization, security hardening

## Problem Statement

Naive Docker images bloat to 1GB+ by including compilers, dev dependencies, and build artifacts. This project shows how to produce a minimal, secure production image using multi-stage builds — reducing attack surface and deploy time.

## Architecture

```
Docker Build Pipeline
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Stage 1: deps                                              │
│  ┌────────────────────────────┐                            │
│  │  FROM node:20-alpine       │                            │
│  │  Install production deps   │  ← Only package.json       │
│  │  (npm ci --omit=dev)       │     copied, no source      │
│  └────────────────────────────┘                            │
│                                                             │
│  Stage 2: builder                                           │
│  ┌────────────────────────────┐                            │
│  │  FROM node:20-alpine       │                            │
│  │  COPY --from=deps          │  ← node_modules from       │
│  │  Copy source               │     stage 1                │
│  │  Run build (tsc/webpack)   │                            │
│  └────────────────────────────┘                            │
│                                                             │
│  Stage 3: test (CI only, not shipped)                       │
│  ┌────────────────────────────┐                            │
│  │  FROM builder              │                            │
│  │  Install dev deps          │  ← Runs in CI pipeline     │
│  │  RUN npm test              │     target: test           │
│  └────────────────────────────┘                            │
│                                                             │
│  Stage 4: production  ◄── Final image                       │
│  ┌────────────────────────────┐                            │
│  │  FROM gcr.io/distroless/   │                            │
│  │        nodejs20-debian12   │  ← No shell, no package    │
│  │  COPY --from=builder /dist │     manager, no root        │
│  │  USER nonroot              │                            │
│  │  ~35MB final image         │                            │
│  └────────────────────────────┘                            │
│                                                             │
│  Size comparison:                                           │
│    Naive image:         ~1.2 GB                             │
│    Multi-stage image:   ~35 MB   (-97%)                     │
└─────────────────────────────────────────────────────────────┘
```

## Usage

```bash
# Build production image
docker build --target production -t myapp:latest .

# Build and run tests in CI
docker build --target test -t myapp:test .
docker run --rm myapp:test

# Scan for vulnerabilities
docker scout cves myapp:latest

# Check final image size
docker images myapp:latest
```

## Key Decisions

- **Distroless base** — no shell means attackers can't exec into the container
- **Non-root user** — `USER nonroot` prevents privilege escalation
- **Separate test stage** — test tooling never enters the production image
- **`.dockerignore`** — excludes `node_modules/`, `.git/`, test files from build context

## Production Considerations

- Pin base image digests (not just tags) for reproducible builds: `FROM node:20-alpine@sha256:...`
- Integrate `docker scout` or `trivy` into CI to block on critical CVEs
- Use BuildKit cache mounts (`--mount=type=cache`) for faster CI rebuilds
- Push to private registry (ECR/GCR/ACR) with image signing (cosign/Notary)

## Metrics for Success

- Final image size < 50MB
- Zero critical/high CVEs in production image
- CI build time < 3 minutes with layer caching
