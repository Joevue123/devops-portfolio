#!/usr/bin/env bash
# Bootstraps ArgoCD into a cluster and applies the root App of Apps
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v2.11.0}"
NAMESPACE="argocd"

echo "Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "${NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "Waiting for ArgoCD to be ready..."
kubectl rollout status deployment/argocd-server -n "${NAMESPACE}" --timeout=300s

echo "Retrieving initial admin password..."
kubectl -n "${NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "Change this password immediately: argocd account update-password"

echo "Applying AppProject and root App of Apps..."
kubectl apply -f "$(dirname "$0")/../argocd/projects/portfolio.yaml"
kubectl apply -f "$(dirname "$0")/../argocd/apps/root-app.yaml"

echo ""
echo "ArgoCD is ready. Port-forward with:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  open https://localhost:8080"
