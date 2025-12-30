#!/bin/bash
#
# Forlock Database Restore Script
#
# Usage:
#   ./restore.sh backups/postgres_20241230_120000.sql.gz
#   ./restore.sh --latest                # Restore latest backup
#   ./restore.sh --list                  # List available backups
#

set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

list_backups() {
    echo ""
    echo "Available Backups"
    echo "================="
    echo ""

    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}No backups directory found${NC}"
        exit 0
    fi

    echo "PostgreSQL:"
    ls -lh "$BACKUP_DIR"/postgres_*.sql.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  None"

    echo ""
    echo "Redis:"
    ls -lh "$BACKUP_DIR"/redis_*.rdb 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  None"
    echo ""
}

get_latest() {
    ls -t "$BACKUP_DIR"/postgres_*.sql.gz 2>/dev/null | head -1
}

restore_postgres() {
    local backup_file=$1

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Backup file not found: $backup_file${NC}"
        exit 1
    fi

    echo -e "${YELLOW}WARNING: This will overwrite the current database!${NC}"
    echo ""
    read -p "Are you sure you want to restore from $backup_file? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled."
        exit 0
    fi

    echo ""
    echo -e "${GREEN}Restoring PostgreSQL...${NC}"

    # Stop API to prevent connections
    echo "  Stopping API..."
    docker stop forlock-api 2>/dev/null || docker service scale forlock_api=0 2>/dev/null || true
    sleep 5

    # Restore
    echo "  Restoring database..."
    gunzip -c "$backup_file" | docker exec -i forlock-postgres psql -U vault_user forlock

    # Start API
    echo "  Starting API..."
    docker start forlock-api 2>/dev/null || docker service scale forlock_api=3 2>/dev/null || true

    echo ""
    echo -e "${GREEN}Restore complete!${NC}"
}

# Main
case "${1:-}" in
    --list)
        list_backups
        ;;
    --latest)
        latest=$(get_latest)
        if [ -z "$latest" ]; then
            echo -e "${RED}No backups found in $BACKUP_DIR${NC}"
            exit 1
        fi
        echo "Latest backup: $latest"
        restore_postgres "$latest"
        ;;
    "")
        echo "Usage: $0 <backup-file> | --latest | --list"
        echo ""
        echo "Examples:"
        echo "  $0 backups/postgres_20241230_120000.sql.gz"
        echo "  $0 --latest"
        echo "  $0 --list"
        exit 1
        ;;
    *)
        restore_postgres "$1"
        ;;
esac
