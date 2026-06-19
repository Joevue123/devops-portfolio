# 23 — Tekton Cloud-Native CI/CD Pipeline

**Tier:** Advanced | **Skills:** Tekton, Kubernetes-native CI, Tasks, Pipelines, Triggers

## Problem Statement

Jenkins and GitHub Actions run outside the cluster. Tekton runs CI/CD as Kubernetes-native Pods — pipelines are CRDs, steps are containers, and the entire system scales with the cluster. No Jenkins masters to maintain, no vendor lock-in.

## Architecture

```
Git Push → GitHub Webhook
                │
                ▼
┌───────────────────────────────────────────────────────────────┐
│  Tekton Triggers (EventListener)                             │
│    Validates HMAC signature                                  │
│    Extracts: repo, branch, commit SHA, image tag             │
│    Creates: PipelineRun                                      │
└───────────────────────────────┬───────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│  Pipeline: ci-cd                                             │
│                                                               │
│  Task 1: clone          [Pod: git-clone]                      │
│    └── git clone repo to workspace PVC                       │
│                                                               │
│  Task 2: lint-test      [Pod: node:20-alpine]                 │
│    ├── npm ci                                                 │
│    ├── npm run lint                                           │
│    └── npm test -- --coverage                                 │
│                                                               │
│  Task 3: build-push     [Pod: kaniko]                         │
│    ├── kaniko builds image (no Docker daemon needed)         │
│    └── pushes to ECR with git-SHA tag                        │
│                                                               │
│  Task 4: scan           [Pod: trivy]                          │
│    └── scan image, fail on CRITICAL CVE                      │
│                                                               │
│  Task 5: deploy-staging [Pod: kubectl]                        │
│    └── kubectl set image deployment/api ...                  │
│                                                               │
│  Task 6: smoke-test     [Pod: curl/k6]                        │
│    └── hit /health, run basic assertions                     │
│                                                               │
│  All Tasks share a PersistentVolumeClaim workspace            │
│  Each Task runs as a separate Pod — full K8s isolation        │
└───────────────────────────────────────────────────────────────┘
```

## Usage

```bash
# Install Tekton Pipelines + Triggers + Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Apply all Tekton resources
kubectl apply -f k8s/

# Trigger pipeline manually (without webhook)
tkn pipeline start ci-cd \
  --param repo-url=https://github.com/Joevue123/devops-portfolio \
  --param image-name=myapp \
  --workspace name=source,claimName=pipeline-pvc \
  -n tekton-pipelines

# Watch pipeline run
tkn pipelinerun logs --last -f -n tekton-pipelines

# Open Tekton Dashboard
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
```

## Key Decisions

- **Kaniko over Docker-in-Docker** — builds OCI images without privileged containers or Docker daemon
- **PVC workspace** — Tasks share source code via PersistentVolumeClaim, not S3 artifacts
- **`finally` tasks** — cleanup and notification always run even if pipeline fails
- **Tekton Hub tasks** — reuse community tasks (`git-clone`, `kaniko`, `trivy`) instead of reinventing

## Production Considerations

- Use Tekton Chains for supply-chain security — automatically signs task results and images with cosign
- Store pipeline results (test coverage, image digest) in the PipelineRun status for audit trail
- Set `timeouts.pipeline: 30m` to kill stuck runs that consume PVC space
- Run multiple PipelineRuns in parallel — Tekton scales with the cluster, no concurrency limits

## Metrics for Success

- Pipeline p50 runtime < 6 minutes (parallel tasks where possible)
- Zero shared state between PipelineRuns (workspace isolation)
- All images signed and attested via Tekton Chains
