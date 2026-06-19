# 50 — Security Compliance as Code

Automate SOC2 Type II and CIS Kubernetes Benchmark evidence collection. OPA/Rego policies enforce compliance controls continuously. Daily compliance report generated and stored in S3 for auditors — no manual evidence gathering.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Compliance Controls (mapped to SOC2 CC6, CC7, CC8)                 │
│                                                                      │
│  Preventive Controls (OPA Gatekeeper):                               │
│  ├── CC6.1: Containers must not run as root                          │
│  ├── CC6.6: Images must come from approved registries                │
│  ├── CC6.7: Resource limits required on all containers               │
│  └── CC8.1: No privileged containers                                 │
│                                                                      │
│  Detective Controls (daily audit CronJob):                           │
│  ├── kube-bench — CIS Benchmark scoring                              │
│  ├── Falco rule coverage check                                       │
│  ├── RBAC wildcard scan                                              │
│  ├── Image CVE scan summary (Trivy)                                  │
│  └── Secret rotation compliance (Vault lease ages)                   │
│                                                                      │
│  Evidence Collection:                                                │
│  CronJob (daily 6am) → generate JSON report → upload to S3          │
│  S3: s3://compliance-evidence/YYYY/MM/DD/cluster-report.json         │
│                                                                      │
│  Auditor Access:                                                     │
│  IAM role (read-only S3) → auditor downloads evidence               │
│  No cluster access required for auditors                             │
└──────────────────────────────────────────────────────────────────────┘

Control Framework Mapping:
SOC2 CC6.1  ← RBAC least-privilege + no cluster-admin for developers
SOC2 CC6.6  ← Approved registry enforcement (OPA)
SOC2 CC7.1  ← Falco runtime monitoring
SOC2 CC7.2  ← Vulnerability scanning (Trivy in CI)
SOC2 CC8.1  ← Change management via GitOps + PR reviews
```

## Problem Statement

SOC2 Type II audits require 6-12 months of continuous evidence. Manual evidence collection (screenshots, kubectl outputs) is expensive and error-prone. This project automates evidence generation so engineers don't spend audit prep week gathering data.

## Key Files

```
policies/soc2-gatekeeper.yaml      — OPA constraints for SOC2 CC6 controls
policies/cis-kyverno.yaml          — Kyverno policies for CIS K8s Benchmark
scripts/compliance-report.sh       — generate daily evidence report
scripts/upload-evidence.sh         — upload report to S3 with metadata
k8s/compliance-cronjob.yaml        — daily compliance audit CronJob
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| OPA for preventive controls | Admission webhook blocks non-compliant resources at creation |
| Kyverno for audit reports | Kyverno's policy reports give per-namespace compliance snapshots |
| Evidence in S3 with object lock | Tamper-evident storage; auditors access S3 directly, not cluster |
| Daily cadence | SOC2 Type II requires evidence over time — daily is sufficient |
| Control → framework mapping in metadata | Each policy annotated with SOC2/ISO27001 control ID |

## Usage

```bash
# Deploy compliance policies
kubectl apply -f policies/

# Run immediate compliance check
kubectl create job compliance-check-manual \
  --from=cronjob/compliance-audit -n compliance

# View compliance report
aws s3 cp s3://compliance-evidence/$(date +%Y/%m/%d)/report.json /tmp/report.json
cat /tmp/report.json | jq '.summary'

# Check Kyverno policy reports
kubectl get policyreport -A -o json | jq '
  .items[] |
  {
    namespace: .metadata.namespace,
    pass: (.results | map(select(.result == "pass")) | length),
    fail: (.results | map(select(.result == "fail")) | length)
  }
'

# Run CIS benchmark
kubectl apply -f k8s/kube-bench-job.yaml
kubectl logs -l job-name=kube-bench -n compliance
```

## SOC2 Control Evidence (auto-collected daily)

| Control | Evidence | Collection Method |
|---------|----------|-------------------|
| CC6.1 No cluster-admin for devs | ClusterRoleBinding dump | kubectl get clusterrolebindings |
| CC6.6 Approved images only | Admission webhook violations (0) | OPA constraint violations |
| CC6.7 MFA for access | Okta audit logs | Okta API |
| CC7.1 Runtime monitoring | Falco event counts by severity | Prometheus query |
| CC7.2 Vuln scanning | Trivy scan pass rate in CI | GitHub Actions API |
| CC8.1 Change management | All PRs required 2 reviews | GitHub API (no bypass merges) |

## Production Considerations

- **Control testing** — annually test that OPA policies actually block what they should
- **Evidence retention** — S3 with Object Lock (WORM); minimum 7 years for SOC2
- **Auditor access** — dedicated IAM role with S3 read-only; no cluster kubeconfig
- **Gap remediation tracking** — failed controls create GitHub issues automatically

## Success Metrics

- Audit prep time: < 2 hours (vs. 2-4 weeks manual)
- OPA preventive control coverage: 100% of SOC2 CC6 controls
- Daily evidence completeness: > 99% of days with successful uploads
- CIS Benchmark score: > 85% PASS
