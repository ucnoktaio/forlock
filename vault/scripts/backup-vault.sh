#!/bin/bash
# Backup Vault data using Raft snapshots

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_CONTAINER="${VAULT_CONTAINER:-forlock-vault}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
DATE=$(date +%Y%m%d_%H%M%S)
ENCRYPT="${ENCRYPT:-true}"

echo -e "${GREEN}=== Vault Backup ===${NC}"
echo ""

# Check VAULT_TOKEN
if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}VAULT_TOKEN not set${NC}"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

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

# Create Raft snapshot
SNAPSHOT_NAME="vault-snapshot-${DATE}.snap"
echo -e "${YELLOW}Creating Raft snapshot...${NC}"

if command -v vault &> /dev/null; then
    vault operator raft snapshot save "${BACKUP_DIR}/${SNAPSHOT_NAME}"
else
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" -e VAULT_ADDR="$VAULT_ADDR" \
        "$VAULT_CONTAINER" vault operator raft snapshot save "/tmp/${SNAPSHOT_NAME}"
    docker cp "${VAULT_CONTAINER}:/tmp/${SNAPSHOT_NAME}" "${BACKUP_DIR}/${SNAPSHOT_NAME}"
    docker exec "$VAULT_CONTAINER" rm "/tmp/${SNAPSHOT_NAME}"
fi

echo -e "${GREEN}Snapshot created: ${SNAPSHOT_NAME}${NC}"

# Encrypt if requested
if [ "$ENCRYPT" = "true" ]; then
    echo -e "${YELLOW}Encrypting backup...${NC}"

    if [ -z "$GPG_RECIPIENT" ]; then
        # Use symmetric encryption
        gpg --symmetric --cipher-algo AES256 \
            -o "${BACKUP_DIR}/${SNAPSHOT_NAME}.gpg" \
            "${BACKUP_DIR}/${SNAPSHOT_NAME}"
    else
        # Use asymmetric encryption
        gpg --encrypt --recipient "$GPG_RECIPIENT" \
            -o "${BACKUP_DIR}/${SNAPSHOT_NAME}.gpg" \
            "${BACKUP_DIR}/${SNAPSHOT_NAME}"
    fi

    # Remove unencrypted snapshot
    rm "${BACKUP_DIR}/${SNAPSHOT_NAME}"
    SNAPSHOT_NAME="${SNAPSHOT_NAME}.gpg"
    echo -e "${GREEN}Backup encrypted${NC}"
fi

# Calculate checksum
CHECKSUM=$(sha256sum "${BACKUP_DIR}/${SNAPSHOT_NAME}" | cut -d' ' -f1)
echo "$CHECKSUM  ${SNAPSHOT_NAME}" > "${BACKUP_DIR}/${SNAPSHOT_NAME}.sha256"

# Display summary
FILESIZE=$(ls -lh "${BACKUP_DIR}/${SNAPSHOT_NAME}" | awk '{print $5}')
echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo "  File: ${BACKUP_DIR}/${SNAPSHOT_NAME}"
echo "  Size: ${FILESIZE}"
echo "  SHA256: ${CHECKSUM}"
echo ""

# Cleanup old backups (keep last 7 days)
echo -e "${YELLOW}Cleaning up old backups...${NC}"
find "$BACKUP_DIR" -name "vault-snapshot-*.snap*" -mtime +7 -delete
find "$BACKUP_DIR" -name "vault-snapshot-*.sha256" -mtime +7 -delete
echo -e "${GREEN}Cleanup complete${NC}"
