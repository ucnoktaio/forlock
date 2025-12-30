#!/bin/bash
# Restore Vault from Raft snapshot

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_CONTAINER="${VAULT_CONTAINER:-forlock-vault}"

echo -e "${GREEN}=== Vault Restore ===${NC}"
echo ""

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <snapshot-file>"
    echo ""
    echo "Examples:"
    echo "  $0 ./backups/vault-snapshot-20251230_120000.snap"
    echo "  $0 ./backups/vault-snapshot-20251230_120000.snap.gpg"
    exit 1
fi

SNAPSHOT_FILE="$1"

if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo -e "${RED}File not found: $SNAPSHOT_FILE${NC}"
    exit 1
fi

# Check VAULT_TOKEN
if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}VAULT_TOKEN not set${NC}"
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
    echo -e "${RED}Vault is not accessible or is sealed${NC}"
    exit 1
fi

# Decrypt if encrypted
RESTORE_FILE="$SNAPSHOT_FILE"
if [[ "$SNAPSHOT_FILE" == *.gpg ]]; then
    echo -e "${YELLOW}Decrypting backup...${NC}"
    TEMP_FILE=$(mktemp)
    gpg --decrypt -o "$TEMP_FILE" "$SNAPSHOT_FILE"
    RESTORE_FILE="$TEMP_FILE"
    echo -e "${GREEN}Decrypted${NC}"
fi

# Verify checksum if available
CHECKSUM_FILE="${SNAPSHOT_FILE%.gpg}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    echo -e "${YELLOW}Verifying checksum...${NC}"
    EXPECTED=$(cat "$CHECKSUM_FILE" | cut -d' ' -f1)
    ACTUAL=$(sha256sum "$RESTORE_FILE" | cut -d' ' -f1)

    if [ "$EXPECTED" != "$ACTUAL" ]; then
        echo -e "${RED}Checksum mismatch!${NC}"
        echo "  Expected: $EXPECTED"
        echo "  Actual:   $ACTUAL"
        exit 1
    fi
    echo -e "${GREEN}Checksum verified${NC}"
fi

# Confirm restore
echo ""
echo -e "${RED}WARNING: This will restore Vault to a previous state.${NC}"
echo -e "${RED}All data added after the snapshot will be lost!${NC}"
echo ""
read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 0
fi

# Perform restore
echo ""
echo -e "${YELLOW}Restoring snapshot...${NC}"

if command -v vault &> /dev/null; then
    vault operator raft snapshot restore -force "$RESTORE_FILE"
else
    docker cp "$RESTORE_FILE" "${VAULT_CONTAINER}:/tmp/restore-snapshot.snap"
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" -e VAULT_ADDR="$VAULT_ADDR" \
        "$VAULT_CONTAINER" vault operator raft snapshot restore -force /tmp/restore-snapshot.snap
    docker exec "$VAULT_CONTAINER" rm /tmp/restore-snapshot.snap
fi

# Cleanup temp file
[ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"

echo ""
echo -e "${GREEN}=== Restore Complete ===${NC}"
echo ""
echo -e "${YELLOW}Note: You may need to unseal Vault again after restore.${NC}"
