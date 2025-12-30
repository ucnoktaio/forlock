#!/bin/bash
# Initialize Vault for first-time setup
# WARNING: Only run this once on a fresh Vault installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_CONTAINER="${VAULT_CONTAINER:-forlock-vault}"
KEY_SHARES="${KEY_SHARES:-5}"
KEY_THRESHOLD="${KEY_THRESHOLD:-3}"

echo -e "${GREEN}=== Vault Initialization ===${NC}"
echo ""
echo -e "${RED}WARNING: This will initialize Vault and generate unseal keys.${NC}"
echo -e "${RED}Only run this on a fresh Vault installation!${NC}"
echo ""
read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Function to run vault commands
vault_cmd() {
    if command -v vault &> /dev/null; then
        VAULT_ADDR="$VAULT_ADDR" vault "$@"
    else
        docker exec -e VAULT_ADDR="$VAULT_ADDR" "$VAULT_CONTAINER" vault "$@"
    fi
}

# Check if already initialized
echo -e "${YELLOW}Checking Vault status...${NC}"
STATUS=$(vault_cmd status -format=json 2>/dev/null || echo '{"initialized": false}')

if echo "$STATUS" | grep -q '"initialized": true'; then
    echo -e "${YELLOW}Vault is already initialized.${NC}"

    if echo "$STATUS" | grep -q '"sealed": true'; then
        echo -e "${RED}Vault is sealed. Please unseal it first.${NC}"
        echo "Run: ./unseal-vault.sh"
    else
        echo -e "${GREEN}Vault is unsealed and ready.${NC}"
    fi
    exit 0
fi

# Initialize Vault
echo ""
echo -e "${YELLOW}Initializing Vault...${NC}"
echo "  Key Shares: $KEY_SHARES"
echo "  Key Threshold: $KEY_THRESHOLD"
echo ""

INIT_OUTPUT=$(vault_cmd operator init \
    -key-shares="$KEY_SHARES" \
    -key-threshold="$KEY_THRESHOLD" \
    -format=json)

# Extract keys and root token
UNSEAL_KEYS=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]')
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')

# Display keys
echo ""
echo -e "${GREEN}=== VAULT INITIALIZED SUCCESSFULLY ===${NC}"
echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  CRITICAL: SAVE THESE KEYS SECURELY - THEY CANNOT BE RECOVERED ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Unseal Keys:${NC}"
KEY_NUM=1
for KEY in $UNSEAL_KEYS; do
    echo "  Key $KEY_NUM: $KEY"
    KEY_NUM=$((KEY_NUM + 1))
done
echo ""
echo -e "${YELLOW}Root Token:${NC}"
echo "  $ROOT_TOKEN"
echo ""
echo -e "${RED}IMPORTANT:${NC}"
echo "  1. Store each unseal key with a different administrator"
echo "  2. Store the root token in a secure password manager"
echo "  3. Require $KEY_THRESHOLD of $KEY_SHARES keys to unseal Vault"
echo "  4. Consider using auto-unseal for production (AWS KMS, Azure Key Vault, etc.)"
echo ""

# Save to file (optional)
KEYS_FILE="vault-keys-$(date +%Y%m%d_%H%M%S).json"
echo "$INIT_OUTPUT" > "$KEYS_FILE"
chmod 600 "$KEYS_FILE"
echo -e "${YELLOW}Keys saved to: $KEYS_FILE${NC}"
echo -e "${RED}Delete this file after securely storing the keys!${NC}"
echo ""

# Unseal Vault
echo -e "${YELLOW}Unsealing Vault...${NC}"
KEY_NUM=1
for KEY in $UNSEAL_KEYS; do
    if [ $KEY_NUM -le $KEY_THRESHOLD ]; then
        vault_cmd operator unseal "$KEY" > /dev/null
        echo "  Applied key $KEY_NUM"
    fi
    KEY_NUM=$((KEY_NUM + 1))
done

echo ""
echo -e "${GREEN}Vault is now unsealed and ready!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. export VAULT_TOKEN=$ROOT_TOKEN"
echo "  2. ./setup-vault.sh"
echo ""
