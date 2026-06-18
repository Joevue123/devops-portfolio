#!/bin/sh
set -e

echo "Configuring Vault..."

# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2

# Write a sample secret
vault kv put secret/api/production \
  db_password="supersecret" \
  api_key="abc123xyz"

# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth (requires cluster access in production)
# vault write auth/kubernetes/config \
#   kubernetes_host="https://kubernetes.default.svc" \
#   kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
#   token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Create a policy for the API service
vault policy write api-policy - <<'EOF'
path "secret/data/api/*" {
  capabilities = ["read"]
}
path "secret/metadata/api/*" {
  capabilities = ["list"]
}
EOF

# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL dynamic credentials
vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/appdb?sslmode=disable" \
  allowed_roles="api-role" \
  username="vault_admin" \
  password="vaultpassword"

# Create a role that generates short-lived DB credentials
vault write database/roles/api-role \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

echo "Vault initialized successfully."
echo "  Static secret:  vault kv get secret/api/production"
echo "  Dynamic DB cred: vault read database/creds/api-role"
