#!/bin/bash
# Forlock Vault Setup Script
# This script configures Vault for use with Forlock

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_CONTAINER="${VAULT_CONTAINER:-forlock-vault}"
FORLOCK_MOUNT_PATH="forlock"

echo -e "${GREEN}=== Forlock Vault Setup ===${NC}"
echo "Vault Address: $VAULT_ADDR"
echo ""

# Check if running in container context
if [ -n "$VAULT_TOKEN" ]; then
    echo -e "${GREEN}Using VAULT_TOKEN from environment${NC}"
else
    echo -e "${YELLOW}VAULT_TOKEN not set. Please set it or login first.${NC}"
    echo "Run: export VAULT_TOKEN=<your-root-token>"
    exit 1
fi

# Function to run vault commands
vault_cmd() {
    if command -v vault &> /dev/null; then
        vault "$@"
    else
        docker exec -e VAULT_TOKEN="$VAULT_TOKEN" -e VAULT_ADDR="$VAULT_ADDR" \
            "$VAULT_CONTAINER" vault "$@"
    fi
}

# Check Vault status
echo -e "${YELLOW}Checking Vault status...${NC}"
if ! vault_cmd status > /dev/null 2>&1; then
    echo -e "${RED}Error: Vault is not accessible or is sealed${NC}"
    echo "Please ensure Vault is running and unsealed."
    exit 1
fi
echo -e "${GREEN}Vault is accessible and unsealed${NC}"
echo ""

# Enable KV secrets engine
echo -e "${YELLOW}Enabling KV v2 secrets engine at '${FORLOCK_MOUNT_PATH}'...${NC}"
if vault_cmd secrets list | grep -q "^${FORLOCK_MOUNT_PATH}/"; then
    echo -e "${GREEN}KV secrets engine already enabled${NC}"
else
    vault_cmd secrets enable -path="${FORLOCK_MOUNT_PATH}" kv-v2
    echo -e "${GREEN}KV secrets engine enabled${NC}"
fi
echo ""

# Create policies
echo -e "${YELLOW}Creating Vault policies...${NC}"

# API Policy
vault_cmd policy write forlock-api - <<EOF
# Forlock API Policy
path "forlock/data/*" {
  capabilities = ["read", "list"]
}
path "forlock/metadata/*" {
  capabilities = ["read", "list"]
}
path "database/creds/forlock-app" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
echo -e "${GREEN}Created 'forlock-api' policy${NC}"

# Admin Policy
vault_cmd policy write forlock-admin - <<EOF
# Forlock Admin Policy
path "forlock/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/policies/acl/forlock-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "auth/approle/role/forlock-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "auth/approle/role/forlock-*/secret-id" {
  capabilities = ["create", "update"]
}
path "auth/approle/role/forlock-*/role-id" {
  capabilities = ["read"]
}
EOF
echo -e "${GREEN}Created 'forlock-admin' policy${NC}"
echo ""

# Enable AppRole auth
echo -e "${YELLOW}Enabling AppRole authentication...${NC}"
if vault_cmd auth list | grep -q "^approle/"; then
    echo -e "${GREEN}AppRole auth already enabled${NC}"
else
    vault_cmd auth enable approle
    echo -e "${GREEN}AppRole auth enabled${NC}"
fi
echo ""

# Create AppRole for Forlock API
echo -e "${YELLOW}Creating AppRole for Forlock API...${NC}"
vault_cmd write auth/approle/role/forlock-api \
    secret_id_ttl=0 \
    token_ttl=1h \
    token_max_ttl=4h \
    token_policies="forlock-api"
echo -e "${GREEN}Created 'forlock-api' AppRole${NC}"
echo ""

# Get Role ID
echo -e "${YELLOW}Retrieving AppRole credentials...${NC}"
ROLE_ID=$(vault_cmd read -field=role_id auth/approle/role/forlock-api/role-id)
SECRET_ID=$(vault_cmd write -field=secret_id -f auth/approle/role/forlock-api/secret-id)

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "${YELLOW}AppRole Credentials (save these securely):${NC}"
echo "----------------------------------------"
echo "VAULT_ROLE_ID=$ROLE_ID"
echo "VAULT_SECRET_ID=$SECRET_ID"
echo "----------------------------------------"
echo ""
echo -e "${YELLOW}Add these to your .env.secrets file:${NC}"
echo ""
echo "VAULT__ENABLED=true"
echo "VAULT__ADDRESS=$VAULT_ADDR"
echo "VAULT__AUTH_METHOD=approle"
echo "VAULT__ROLE_ID=$ROLE_ID"
echo "VAULT__SECRET_ID=$SECRET_ID"
echo "VAULT__MOUNT_PATH=$FORLOCK_MOUNT_PATH"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Store the secrets in Vault:"
echo "   ./vault/scripts/store-secrets.sh"
echo ""
echo "2. Update your docker-compose.yml to use Vault"
echo ""
