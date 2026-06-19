#!/usr/bin/env bash
# Promote secondary RDS cluster to primary during regional outage
set -euo pipefail

GLOBAL_CLUSTER_ID="${GLOBAL_CLUSTER_ID:-production-global}"
TARGET_REGION="${1:-eu-west-1}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

log()  { echo "[$(date -u '+%H:%M:%S')] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

notify_slack() {
  local msg="$1"
  [[ -z "${SLACK_WEBHOOK}" ]] && return
  curl -sf -X POST "${SLACK_WEBHOOK}" \
    -H 'Content-type: application/json' \
    --data "{\"text\": \"[FAILOVER] ${msg}\"}" || true
}

log "==> Starting failover to ${TARGET_REGION}"
notify_slack "Failover initiated: promoting ${TARGET_REGION} RDS to primary"

# 1. Verify global cluster exists
aws rds describe-global-clusters \
  --global-cluster-identifier "${GLOBAL_CLUSTER_ID}" \
  --region us-east-1 \
  --query 'GlobalClusters[0].Status' --output text | grep -q "available" \
  || fail "Global cluster not found or not available"

# 2. Confirm the target is a secondary member
TARGET_CLUSTER_ARN=$(aws rds describe-global-clusters \
  --global-cluster-identifier "${GLOBAL_CLUSTER_ID}" \
  --region us-east-1 \
  --query "GlobalClusters[0].GlobalClusterMembers[?!IsWriter].DBClusterArn | [0]" \
  --output text)

[[ -z "${TARGET_CLUSTER_ARN}" ]] && fail "No secondary cluster found to promote"
log "Target cluster ARN: ${TARGET_CLUSTER_ARN}"

# 3. Failover (promotes secondary to primary, demotes primary to secondary)
log "==> Initiating RDS Global Database failover..."
aws rds failover-global-cluster \
  --global-cluster-identifier "${GLOBAL_CLUSTER_ID}" \
  --target-db-cluster-identifier "${TARGET_CLUSTER_ARN}" \
  --region us-east-1

# 4. Wait for promotion to complete
log "==> Waiting for ${TARGET_REGION} cluster to become primary..."
for i in $(seq 1 30); do
  STATUS=$(aws rds describe-global-clusters \
    --global-cluster-identifier "${GLOBAL_CLUSTER_ID}" \
    --region "${TARGET_REGION}" \
    --query "GlobalClusters[0].GlobalClusterMembers[?DBClusterArn=='${TARGET_CLUSTER_ARN}'].IsWriter | [0]" \
    --output text 2>/dev/null || echo "false")

  if [[ "${STATUS}" == "True" ]]; then
    log "==> ${TARGET_REGION} is now the primary writer"
    break
  fi

  log "  Still waiting... (${i}/30)"
  sleep 10
done

[[ "${STATUS}" != "True" ]] && fail "Failover timed out after 5 minutes"

# 5. Verify the new primary is writable
log "==> Verifying new primary endpoint..."
NEW_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier "$(basename "${TARGET_CLUSTER_ARN}")" \
  --region "${TARGET_REGION}" \
  --query 'DBClusters[0].Endpoint' --output text)

log "  New write endpoint: ${NEW_ENDPOINT}"

notify_slack "Failover complete. Write endpoint: ${NEW_ENDPOINT}. Update application config."
log "==> Failover complete. Next: update app DB_WRITE_HOST to ${NEW_ENDPOINT}"
