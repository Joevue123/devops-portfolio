#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a CAPI management cluster using kind, then initialize AWS provider

AWS_REGION="${AWS_REGION:-us-east-1}"
CAPI_VERSION="${CAPI_VERSION:-v1.7.0}"
CAPA_VERSION="${CAPA_VERSION:-v2.5.0}"

echo "==> Creating kind management cluster..."
kind create cluster --name capi-management --config - <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
EOF

echo "==> Generating CAPA credentials..."
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

echo "==> Initializing CAPI management cluster..."
clusterctl init \
  --infrastructure aws:"${CAPA_VERSION}" \
  --core cluster-api:"${CAPI_VERSION}" \
  --bootstrap kubeadm:"${CAPI_VERSION}" \
  --control-plane kubeadm:"${CAPI_VERSION}"

echo "==> Waiting for CAPI controllers to be ready..."
kubectl wait --for=condition=Available \
  deployment/capi-controller-manager \
  deployment/capa-controller-manager \
  deployment/capi-kubeadm-bootstrap-controller-manager \
  deployment/capi-kubeadm-control-plane-controller-manager \
  -n capi-system --timeout=5m

echo "==> Creating namespace for workload clusters..."
kubectl create namespace capi-clusters --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Management cluster ready. Apply workload cluster manifests:"
echo "  kubectl apply -f clusters/staging-cluster.yaml"
echo "  kubectl apply -f workers/machine-deployment.yaml"
echo ""
echo "Watch cluster provision:"
echo "  clusterctl describe cluster staging -n capi-clusters"
