# Forlock Admin Policy
# Grants full access to Forlock secrets for administrators

# KV v2 secrets engine - full access
path "forlock/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage policies
path "sys/policies/acl/forlock-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage auth methods
path "auth/approle/role/forlock-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Generate role credentials
path "auth/approle/role/forlock-*/secret-id" {
  capabilities = ["create", "update"]
}

path "auth/approle/role/forlock-*/role-id" {
  capabilities = ["read"]
}

# Database secrets engine management
path "database/config/forlock-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "database/roles/forlock-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Audit log access
path "sys/audit" {
  capabilities = ["read", "list"]
}

path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete"]
}

# Token management
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
