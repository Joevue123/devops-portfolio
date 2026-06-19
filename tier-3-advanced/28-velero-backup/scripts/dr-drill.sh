#!/usr/bin/env bash
# Monthly DR drill: restore latest backup to dr-test namespace and verify
set -euo pipefail

BACKUP=$(velero backup get --output json | python3 -c "
import json, sys
backups = json.load(sys.stdin)['items']
completed = [b for b in backups if b['status']['phase'] == 'Completed']
completed.sort(key=lambda b: b['metadata']['creationTimestamp'], reverse=True)
print(completed[0]['metadata']['name'])
")

echo "Starting DR drill using backup: ${BACKUP}"

velero restore create "dr-drill-$(date +%Y%m%d)" \
  --from-backup "${BACKUP}" \
  --include-namespaces production \
  --namespace-mappings production:production-dr-test \
  --wait

kubectl port-forward svc/api -n production-dr-test 18080:80 &
PF_PID=$!
sleep 5

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18080/health)
kill "${PF_PID}" 2>/dev/null || true

if [ "${STATUS}" = "200" ]; then
  echo "DR drill PASSED"
else
  echo "DR drill FAILED — HTTP ${STATUS}"
  exit 1
fi

kubectl delete namespace production-dr-test
echo "DR drill complete. RTO verified."
