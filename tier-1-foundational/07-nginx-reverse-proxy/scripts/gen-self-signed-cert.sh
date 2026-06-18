#!/usr/bin/env bash
# Generates a self-signed TLS certificate for local development
set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/certs"
mkdir -p "${CERT_DIR}"

openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "${CERT_DIR}/server.key" \
    -out "${CERT_DIR}/server.crt" \
    -days 365 \
    -subj "/C=US/ST=Dev/L=Dev/O=Dev/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "Certificate generated in ${CERT_DIR}/"
echo "  server.crt  — public certificate"
echo "  server.key  — private key (keep secret)"
