#!/bin/bash
# Unseal Vault after restart
# Requires threshold number of unseal keys

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_CONTAINER="${VAULT_CONTAINER:-forlock-vault}"

echo -e "${GREEN}=== Vault Unseal ===${NC}"
echo ""

# Function to run vault commands
vault_cmd() {
    if command -v vault &> /dev/null; then
        VAULT_ADDR="$VAULT_ADDR" vault "$@"
    else
        docker exec -e VAULT_ADDR="$VAULT_ADDR" "$VAULT_CONTAINER" vault "$@"
    fi
}

# Check status
echo -e "${YELLOW}Checking Vault status...${NC}"
STATUS=$(vault_cmd status -format=json 2>/dev/null || echo '{"sealed": true, "initialized": false}')

INITIALIZED=$(echo "$STATUS" | jq -r '.initialized')
SEALED=$(echo "$STATUS" | jq -r '.sealed')
THRESHOLD=$(echo "$STATUS" | jq -r '.t // 3')

if [ "$INITIALIZED" != "true" ]; then
    echo -e "${RED}Vault is not initialized.${NC}"
    echo "Run: ./init-vault.sh"
    exit 1
fi

if [ "$SEALED" != "true" ]; then
    echo -e "${GREEN}Vault is already unsealed.${NC}"
    exit 0
fi

PROGRESS=$(echo "$STATUS" | jq -r '.progress // 0')
echo "Unseal Progress: $PROGRESS/$THRESHOLD"
echo ""

# Unseal loop
KEYS_APPLIED=$PROGRESS
while [ $KEYS_APPLIED -lt $THRESHOLD ]; do
    REMAINING=$((THRESHOLD - KEYS_APPLIED))
    echo -e "${YELLOW}Enter unseal key ($REMAINING more needed):${NC}"
    read -s UNSEAL_KEY

    if [ -z "$UNSEAL_KEY" ]; then
        echo -e "${RED}No key entered. Aborting.${NC}"
        exit 1
    fi

    RESULT=$(vault_cmd operator unseal -format=json "$UNSEAL_KEY" 2>&1)

    if echo "$RESULT" | grep -q '"sealed": false'; then
        echo -e "${GREEN}Vault is now unsealed!${NC}"
        exit 0
    elif echo "$RESULT" | grep -q '"sealed": true'; then
        KEYS_APPLIED=$(echo "$RESULT" | jq -r '.progress')
        echo -e "${GREEN}Key accepted. Progress: $KEYS_APPLIED/$THRESHOLD${NC}"
    else
        echo -e "${RED}Invalid key or error occurred.${NC}"
    fi
done

echo ""
echo -e "${GREEN}=== Vault Unsealed Successfully ===${NC}"
