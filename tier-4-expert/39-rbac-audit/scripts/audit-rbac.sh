#!/usr/bin/env bash
# RBAC audit: find over-privileged ServiceAccounts and ClusterRoleBindings
set -euo pipefail

echo "============================================================"
echo " Kubernetes RBAC Audit Report"
echo " $(date)"
echo "============================================================"

echo ""
echo "── 1. ClusterRoleBindings to cluster-admin ──────────────────"
kubectl get clusterrolebindings -o json | jq -r '
  .items[] |
  select(.roleRef.name == "cluster-admin") |
  "BINDING: \(.metadata.name)\n  SUBJECTS: \([.subjects[]? | "\(.kind)/\(.name)"] | join(", "))\n"
'

echo ""
echo "── 2. Roles with wildcard verbs or resources ─────────────────"
kubectl get clusterroles,roles -A -o json | jq -r '
  .items[] |
  . as $role |
  .rules[]? |
  select((.verbs | index("*")) or (.resources | index("*")) or (.apiGroups | index("*"))) |
  "ROLE: \($role.metadata.name) (ns: \($role.metadata.namespace // "cluster-wide"))\n  \(. | tojson)\n"
'

echo ""
echo "── 3. ServiceAccounts with automountServiceAccountToken: true ─"
kubectl get serviceaccounts -A -o json | jq -r '
  .items[] |
  select((.automountServiceAccountToken // true) == true) |
  select(.metadata.name != "default" or .metadata.namespace != "kube-system") |
  "\(.metadata.namespace)/\(.metadata.name)"
' | sort | head -30
echo "  (showing first 30; pipe to grep to filter)"

echo ""
echo "── 4. Pods with hostPID / hostNetwork / privileged ───────────"
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(
    .spec.hostPID == true or
    .spec.hostNetwork == true or
    (.spec.containers[].securityContext.privileged // false) == true
  ) |
  "\(.metadata.namespace)/\(.metadata.name): hostPID=\(.spec.hostPID // false) hostNetwork=\(.spec.hostNetwork // false)"
'

echo ""
echo "── 5. RBAC summary ───────────────────────────────────────────"
echo "ClusterRoles:        $(kubectl get clusterroles | wc -l)"
echo "ClusterRoleBindings: $(kubectl get clusterrolebindings | wc -l)"
echo "Roles (all ns):      $(kubectl get roles -A | wc -l)"
echo "RoleBindings (all):  $(kubectl get rolebindings -A | wc -l)"

echo ""
echo "── 6. Recommended actions ────────────────────────────────────"
echo "  - Replace cluster-admin bindings with namespace-scoped Roles"
echo "  - Set automountServiceAccountToken: false on all ServiceAccounts"
echo "  - Remove wildcard (*) from verbs/resources in Roles"
echo "  - Run: kube-bench for CIS compliance score"
echo ""
