# Policy for the API service — read-only access to its own secrets
path "secret/data/api/*" {
  capabilities = ["read"]
}

path "secret/metadata/api/*" {
  capabilities = ["list", "read"]
}

# Allow reading dynamic database credentials
path "database/creds/api-role" {
  capabilities = ["read"]
}

# Allow renewing own leases
path "sys/leases/renew" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
