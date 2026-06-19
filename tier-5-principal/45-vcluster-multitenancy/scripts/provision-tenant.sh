#!/usr/bin/env bash
# Provision a new team vCluster — idempotent, GitOps-friendly
set -euo pipefail

TEAM="${TEAM:-}"
ENV="${ENV:-dev}"
CPU_LIMIT="${CPU_LIMIT:-8}"
MEMORY_LIMIT="${MEMORY_LIMIT:-16Gi}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

usage() {
  echo "Usage: $0 --team <name> --env <dev|staging|prod> [--cpu-limit 16] [--memory-limit 32Gi]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --team)         TEAM="$2";         shift 2 ;;
    --env)          ENV="$2";          shift 2 ;;
    --cpu-limit)    CPU_LIMIT="$2";    shift 2 ;;
    --memory-limit) MEMORY_LIMIT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "${TEAM}" ]] && usage

NS="team-${TEAM}"
VCLUSTER_NAME="${TEAM}-${ENV}"

echo "==> Provisioning vCluster: ${VCLUSTER_NAME} in namespace ${NS}"

# 1. Create host namespace with labels and quotas
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS}
  labels:
    team: ${TEAM}
    vcluster-managed: "true"
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: ${NS}
spec:
  hard:
    requests.cpu: "${CPU_LIMIT}"
    requests.memory: "${MEMORY_LIMIT}"
    limits.cpu: "$(echo "${CPU_LIMIT}" | sed 's/[^0-9]*//g' | awk '{print $1*2}' | sed 's/[^0-9]*//')"
    count/pods: "200"
EOF

# 2. Create ArgoCD Application for vCluster (GitOps manages the actual vCluster)
kubectl apply -n "${ARGOCD_NAMESPACE}" -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vcluster-${VCLUSTER_NAME}
  namespace: ${ARGOCD_NAMESPACE}
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: platform
  source:
    repoURL: https://charts.loft.sh
    chart: vcluster
    targetRevision: 0.19.x
    helm:
      values: |
        vcluster:
          image: rancher/k3s:v1.30.0-k3s1
        sync:
          ingresses:
            enabled: true
          networkpolicies:
            enabled: true
        syncer:
          extraArgs:
            - --tls-san=${VCLUSTER_NAME}.${NS}.svc.cluster.local
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: "2"
            memory: 2Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NS}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
EOF

echo "==> Waiting for vCluster to be ready..."
kubectl wait --for=condition=Ready pod -l "app=vcluster,release=${VCLUSTER_NAME}" \
  -n "${NS}" --timeout=5m

echo "==> Getting kubeconfig..."
vcluster connect "${VCLUSTER_NAME}" -n "${NS}" --update-current=false \
  --server=https://k8s-internal.example.com/vcluster/"${VCLUSTER_NAME}" \
  > "/tmp/${VCLUSTER_NAME}.kubeconfig"

echo ""
echo "vCluster ready!"
echo "  Team kubeconfig: /tmp/${VCLUSTER_NAME}.kubeconfig"
echo "  Store in Vault:  vault kv put secret/teams/${TEAM}/${ENV}/kubeconfig @/tmp/${VCLUSTER_NAME}.kubeconfig"
echo "  Or via ESO:      ExternalSecret syncs from Vault to team namespace"
