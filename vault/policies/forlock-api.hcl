# Forlock API Policy
# Grants read access to Forlock secrets

# KV v2 secrets engine - data path
path "forlock/data/*" {
  capabilities = ["read", "list"]
}

# KV v2 secrets engine - metadata path
path "forlock/metadata/*" {
  capabilities = ["read", "list"]
}

# Dynamic database credentials (if enabled)
path "database/creds/forlock-app" {
  capabilities = ["read"]
}

# Token self-management
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Deny access to other paths (implicit)
