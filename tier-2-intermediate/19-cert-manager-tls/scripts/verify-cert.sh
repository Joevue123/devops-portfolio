#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-production}"
CERT_NAME="${2:-api-tls}"

echo "Checking certificate: ${CERT_NAME} in namespace: ${NAMESPACE}"
kubectl get certificate "${CERT_NAME}" -n "${NAMESPACE}"

echo ""
echo "Certificate conditions:"
kubectl get certificate "${CERT_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{range .status.conditions[*]}{.type}: {.status} — {.message}{"\n"}{end}'

echo ""
echo "TLS secret expiry:"
kubectl get secret "${CERT_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -dates -subject -issuer 2>/dev/null || \
  echo "Secret not yet created — certificate may still be provisioning"
