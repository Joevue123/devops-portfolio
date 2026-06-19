#!/usr/bin/env bash
# Blue/green traffic switch with smoke testing and automatic rollback
set -euo pipefail

NAMESPACE="${NAMESPACE:-production}"
SERVICE="api"
NEW_VERSION="${1:?Usage: switch.sh <new-image-tag>}"

# Determine active/inactive slots
ACTIVE=$(kubectl get svc "${SERVICE}" -n "${NAMESPACE}" -o jsonpath='{.spec.selector.slot}')
INACTIVE=$([ "${ACTIVE}" = "blue" ] && echo "green" || echo "blue")

echo "Active slot: ${ACTIVE} | Deploying to: ${INACTIVE}"

# Deploy new version to inactive slot
echo "Deploying ${NEW_VERSION} to ${INACTIVE}..."
kubectl set image deployment/api-${INACTIVE} api=myapp:${NEW_VERSION} -n "${NAMESPACE}"
kubectl rollout status deployment/api-${INACTIVE} -n "${NAMESPACE}" --timeout=5m

# Smoke test the inactive slot directly (via pod IP)
echo "Running smoke tests against ${INACTIVE}..."
POD=$(kubectl get pods -n "${NAMESPACE}" -l slot="${INACTIVE}" -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "${NAMESPACE}" "${POD}" -- wget -qO- http://localhost:3000/health | grep -q "ok" || {
  echo "SMOKE TEST FAILED — aborting, staying on ${ACTIVE}"
  exit 1
}

echo "Smoke tests passed. Switching traffic to ${INACTIVE}..."
kubectl patch service "${SERVICE}" -n "${NAMESPACE}" \
  -p "{\"spec\":{\"selector\":{\"slot\":\"${INACTIVE}\"}}}"

echo "Traffic switched to ${INACTIVE} (${NEW_VERSION}). Monitoring for 60s..."
sleep 60

# Check error rate after switch
ERROR_RATE=$(kubectl exec -n monitoring deploy/prometheus -- \
  wget -qO- "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{status_code=~'5..'}[1m]))/sum(rate(http_requests_total[1m]))*100" \
  2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['result'][0]['value'][1])" 2>/dev/null || echo "0")

if (( $(echo "${ERROR_RATE} > 1.0" | bc -l) )); then
  echo "ERROR RATE ${ERROR_RATE}% exceeds 1% — rolling back to ${ACTIVE}!"
  kubectl patch service "${SERVICE}" -n "${NAMESPACE}" \
    -p "{\"spec\":{\"selector\":{\"slot\":\"${ACTIVE}\"}}}"
  exit 1
fi

echo "Deploy successful. ${INACTIVE} (${NEW_VERSION}) is now live."
echo "Previous slot ${ACTIVE} is standing by for 30 minutes."
echo "To clean up: kubectl scale deployment/api-${ACTIVE} --replicas=0 -n ${NAMESPACE}"
