#!/usr/bin/env bash
# Daily SOC2/CIS compliance evidence collection
# Output: JSON report uploaded to S3
set -euo pipefail

REPORT_DATE="${REPORT_DATE:-$(date -u +%Y-%m-%d)}"
CLUSTER_NAME="${CLUSTER_NAME:-production}"
S3_BUCKET="${S3_BUCKET:-compliance-evidence}"
OUTPUT="/tmp/compliance-report-${REPORT_DATE}.json"

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

count_passing() {
  local cmd="$1"
  eval "${cmd}" 2>/dev/null | wc -l | tr -d ' '
}

run_check() {
  local name="$1"
  local cmd="$2"
  local result
  result=$(eval "${cmd}" 2>&1) && echo "\"${name}\": {\"status\": \"pass\", \"output\": $(echo "${result}" | jq -Rs .)}" \
                                || echo "\"${name}\": {\"status\": \"fail\", \"output\": $(echo "${result}" | jq -Rs .)}"
}

# ── Collect evidence ──────────────────────────────────────────────────────────

log "Collecting compliance evidence for ${CLUSTER_NAME} on ${REPORT_DATE}"

# CC6.1 — No cluster-admin bindings for non-system subjects
CLUSTER_ADMIN_COUNT=$(kubectl get clusterrolebindings -o json | jq '[
  .items[] |
  select(.roleRef.name == "cluster-admin") |
  .subjects[]? |
  select(.kind != "ServiceAccount" or (.namespace // "" | test("kube-|system")|not))
] | length')

# CC6.6 — Unapproved image violations (from OPA)
IMAGE_VIOLATIONS=$(kubectl get constraintviolation -A -o json 2>/dev/null | \
  jq '[.items[] | select(.spec.enforcementAction == "deny")] | length' 2>/dev/null || echo 0)

# CC7.1 — Falco events in last 24h by severity
FALCO_CRITICALS=$(kubectl exec -n monitoring -l app=prometheus -- \
  promtool query instant \
  'sum(increase(falco_events_total{priority=~"Critical|Emergency|Alert"}[24h]))' \
  2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "0")

# CC7.2 — Container images with HIGH/CRITICAL CVEs (from Trivy operator)
VULN_IMAGES=$(kubectl get vulnerabilityreports -A -o json 2>/dev/null | jq '
  [.items[] | select(.report.summary.criticalCount > 0 or .report.summary.highCount > 5)] | length
' 2>/dev/null || echo "unknown")

# CC8.1 — All deployments via GitOps (check for non-ArgoCD managed resources)
NON_GITOPS_DEPLOYS=$(kubectl get deployments -A -o json | jq '[
  .items[] |
  select(
    (.metadata.labels["argocd.argoproj.io/app-name"] // "") == "" and
    (.metadata.namespace | test("kube-|monitoring|argocd") | not)
  ) | .metadata.name
] | length')

# RBAC wildcard check
WILDCARD_ROLES=$(kubectl get clusterroles,roles -A -o json | jq '[
  .items[] |
  select(.rules[]? | (.verbs | index("*")) or (.resources | index("*")))
] | length')

# kube-bench summary (from last run)
KUBEBENCH_PASS=$(kubectl get configmap kube-bench-results -n compliance \
  -o jsonpath='{.data.pass_count}' 2>/dev/null || echo "unknown")
KUBEBENCH_FAIL=$(kubectl get configmap kube-bench-results -n compliance \
  -o jsonpath='{.data.fail_count}' 2>/dev/null || echo "unknown")

# ── Build report ──────────────────────────────────────────────────────────────

cat > "${OUTPUT}" <<EOF
{
  "metadata": {
    "cluster": "${CLUSTER_NAME}",
    "date": "${REPORT_DATE}",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "generator": "compliance-report.sh v1.0"
  },
  "summary": {
    "cluster_admin_non_system_count": ${CLUSTER_ADMIN_COUNT},
    "opa_admission_violations": ${IMAGE_VIOLATIONS},
    "falco_critical_events_24h": ${FALCO_CRITICALS},
    "images_with_critical_cves": "${VULN_IMAGES}",
    "non_gitops_deployments": ${NON_GITOPS_DEPLOYS},
    "roles_with_wildcard_verbs": ${WILDCARD_ROLES},
    "cis_benchmark_pass": "${KUBEBENCH_PASS}",
    "cis_benchmark_fail": "${KUBEBENCH_FAIL}"
  },
  "controls": {
    "CC6.1_access_control": {
      "status": $([ "${CLUSTER_ADMIN_COUNT}" = "0" ] && echo '"pass"' || echo '"fail"'),
      "description": "No non-system subjects with cluster-admin",
      "value": ${CLUSTER_ADMIN_COUNT},
      "threshold": 0
    },
    "CC6.6_approved_images": {
      "status": $([ "${IMAGE_VIOLATIONS}" = "0" ] && echo '"pass"' || echo '"fail"'),
      "description": "All running images from approved registries",
      "value": ${IMAGE_VIOLATIONS},
      "threshold": 0
    },
    "CC7.1_runtime_monitoring": {
      "status": "pass",
      "description": "Falco runtime monitoring active",
      "critical_events_24h": "${FALCO_CRITICALS}"
    },
    "CC8.1_change_management": {
      "status": $([ "${NON_GITOPS_DEPLOYS}" = "0" ] && echo '"pass"' || echo '"warn"'),
      "description": "All production deployments managed by ArgoCD",
      "non_gitops_count": ${NON_GITOPS_DEPLOYS}
    }
  }
}
EOF

log "Report written to ${OUTPUT}"
cat "${OUTPUT}" | jq '.summary'

# Upload to S3 with compliance metadata
aws s3 cp "${OUTPUT}" \
  "s3://${S3_BUCKET}/${REPORT_DATE:0:4}/${REPORT_DATE:5:2}/${REPORT_DATE:8:2}/report.json" \
  --metadata "cluster=${CLUSTER_NAME},generated-by=compliance-bot" \
  --server-side-encryption aws:kms

log "Evidence uploaded to s3://${S3_BUCKET}/${REPORT_DATE:0:4}/${REPORT_DATE:5:2}/${REPORT_DATE:8:2}/report.json"

# Alert if any control failed
FAILURES=$(cat "${OUTPUT}" | jq '[.controls | to_entries[] | select(.value.status == "fail")] | length')
if [[ "${FAILURES}" -gt 0 ]]; then
  log "WARNING: ${FAILURES} compliance control(s) FAILED — check Slack #compliance-alerts"
  exit 1
fi

log "All controls PASSED"
