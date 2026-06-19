#!/usr/bin/env bash
# Scale non-production namespaces to zero replicas (evening) or restore (morning)
# Designed to run as a Kubernetes CronJob
set -euo pipefail

ACTION="${ACTION:-down}"    # "down" or "up"
NAMESPACES="${NAMESPACES:-dev staging}"
MIN_SCALE="${MIN_SCALE:-0}"

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }

scale_namespace() {
  local ns="$1"
  local replicas="$2"

  log "Scaling namespace ${ns} to ${replicas} replicas..."

  # Annotate current replicas before scaling down (needed for restore)
  if [[ "${replicas}" == "0" ]]; then
    kubectl get deployments -n "${ns}" -o json | jq -r '.items[] | .metadata.name' | while read -r deploy; do
      current=$(kubectl get deployment "${deploy}" -n "${ns}" -o jsonpath='{.spec.replicas}')
      kubectl annotate deployment "${deploy}" -n "${ns}" \
        "autoscaler.kubernetes.io/saved-replicas=${current}" \
        --overwrite
    done
  fi

  # Scale deployments
  kubectl get deployments -n "${ns}" -o name | while read -r deploy; do
    if [[ "${replicas}" == "restore" ]]; then
      saved=$(kubectl get "${deploy}" -n "${ns}" \
        -o jsonpath='{.metadata.annotations.autoscaler\.kubernetes\.io/saved-replicas}' 2>/dev/null || echo "1")
      kubectl scale "${deploy}" -n "${ns}" --replicas="${saved:-1}"
    else
      kubectl scale "${deploy}" -n "${ns}" --replicas="${replicas}"
    fi
  done

  # Scale statefulsets
  kubectl get statefulsets -n "${ns}" -o name | while read -r sts; do
    if [[ "${replicas}" == "restore" ]]; then
      saved=$(kubectl get "${sts}" -n "${ns}" \
        -o jsonpath='{.metadata.annotations.autoscaler\.kubernetes\.io/saved-replicas}' 2>/dev/null || echo "1")
      kubectl scale "${sts}" -n "${ns}" --replicas="${saved:-1}"
    else
      kubectl annotate "${sts}" -n "${ns}" \
        "autoscaler.kubernetes.io/saved-replicas=$(kubectl get ${sts} -n ${ns} -o jsonpath='{.spec.replicas}')" \
        --overwrite
      kubectl scale "${sts}" -n "${ns}" --replicas="${replicas}"
    fi
  done

  log "  Done: ${ns}"
}

case "${ACTION}" in
  down)
    log "==> Evening scale-down: scaling to 0"
    for ns in ${NAMESPACES}; do
      scale_namespace "${ns}" 0
    done
    log "==> Scale-down complete. Karpenter will remove idle nodes."
    ;;
  up)
    log "==> Morning scale-up: restoring saved replicas"
    for ns in ${NAMESPACES}; do
      scale_namespace "${ns}" restore
    done
    log "==> Scale-up complete."
    ;;
  *)
    echo "ACTION must be 'up' or 'down'" >&2
    exit 1
    ;;
esac
