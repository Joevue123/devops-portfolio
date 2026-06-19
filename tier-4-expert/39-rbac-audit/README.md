# 39 — Kubernetes RBAC Audit & Least-Privilege Hardening

Audit existing RBAC permissions with `kubectl-access-matrix` and `audit2rbac`. Replace wildcard ClusterRoles with least-privilege Role/ClusterRole bindings. Run kube-bench CIS benchmarks for compliance scoring.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  RBAC Audit Workflow                                                 │
│                                                                      │
│  1. Discovery Phase                                                  │
│     kubectl-access-matrix — "who can do what to which resource"      │
│     rbac-lookup — "what can this ServiceAccount do?"                 │
│     audit2rbac — replay audit log → minimal ClusterRole              │
│                                                                      │
│  2. CIS Benchmark                                                    │
│     kube-bench Job — scores 200+ control plane checks                │
│     Findings: FAIL on wildcard verbs, WARN on missing audit log      │
│                                                                      │
│  3. Remediation                                                      │
│     Replace: ClusterRole with wildcards → namespace-scoped Role      │
│     Add: ResourceQuota per namespace (limit blast radius)            │
│     Remove: Default ServiceAccount automounting in every namespace   │
│     Enable: Audit logging to S3 (policy: log all RBAC mutations)     │
│                                                                      │
│  4. Ongoing                                                          │
│     rbac-manager — manage bindings via RoleBinding CRD groups        │
│     CI check: conftest validates no new wildcard verbs in PRs        │
└──────────────────────────────────────────────────────────────────────┘
```

## Problem Statement

Most clusters have developers with cluster-admin, service accounts with wildcard permissions, and no audit trail. A compromised pod inheriting `cluster-admin` can read all secrets and exfiltrate data cluster-wide.

## Key Files

```
rbac/namespace-roles.yaml         — least-privilege Role per namespace
rbac/platform-clusterrole.yaml    — ClusterRole for platform team only
rbac/bindings.yaml                — RoleBindings for groups (not individuals)
scripts/audit-rbac.sh             — Discovery + access matrix report
scripts/find-wildcards.sh         — Find all Roles/ClusterRoles with * verbs
kube-bench/job.yaml               — CIS benchmark Job
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Group bindings, not user bindings | Users change teams; binding groups survives offboarding |
| Namespace-scoped Roles over ClusterRoles | ClusterRole = cluster-wide; namespace Role = blast radius limited |
| Disable default SA token automounting | Most apps don't need K8s API access; opt-in instead of opt-out |
| audit2rbac for existing SAs | Generate minimal permissions from real audit log, not guesses |
| OPA Gatekeeper for ongoing enforcement | Block new wildcard roles from ever being created again |

## Usage

```bash
# Install audit tools
kubectl krew install access-matrix rbac-lookup

# Who can do what?
kubectl access-matrix --namespace production

# What can this SA do?
kubectl rbac-lookup api-service-account -o wide

# Find wildcard verbs
./scripts/find-wildcards.sh

# Run CIS benchmark
kubectl apply -f kube-bench/job.yaml
kubectl logs -l app=kube-bench --tail=200

# Apply least-privilege RBAC
kubectl apply -f rbac/

# Verify narrowed permissions
kubectl auth can-i create pods --as=system:serviceaccount:production:api \
  --namespace production    # should be: no
kubectl auth can-i list pods --as=system:serviceaccount:production:api \
  --namespace production    # should be: yes
```

## Production Considerations

- **Audit log retention** — keep K8s audit logs for 90 days minimum (compliance requirement)
- **Quarterly access reviews** — list all ClusterRoleBindings, confirm each is still needed
- **Break-glass procedure** — emergency cluster-admin via time-limited role binding with alert
- **Namespace isolation** — NetworkPolicy + RBAC + ResourceQuota together provide defense-in-depth

## Success Metrics

- Zero service accounts with cluster-admin or wildcard verb permissions
- kube-bench CIS score: > 80% PASS on control plane checks
- All RBAC changes go through Git PR (GitOps for RBAC)
- Audit log completeness: 100% of RBAC mutation events captured
