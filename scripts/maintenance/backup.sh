#!/bin/bash
#
# Forlock Database Backup Script
#
# Usage:
#   ./backup.sh                    # Backup to ./backups/
#   ./backup.sh /path/to/backups   # Backup to custom path
#   ./backup.sh --s3 bucket-name   # Backup to S3
#

set -e

BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running in Swarm mode
SWARM_MODE=false
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    SWARM_MODE=true
fi

# Get container name
get_container() {
    local service=$1
    if [ "$SWARM_MODE" = true ]; then
        docker ps -q -f "name=forlock_${service}" | head -1
    else
        echo "forlock-${service}"
    fi
}

backup_postgres() {
    echo -e "${GREEN}[1/3] Backing up PostgreSQL...${NC}"

    local container=$(get_container "postgres")
    local backup_file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"

    mkdir -p "$BACKUP_DIR"

    if [ "$SWARM_MODE" = true ]; then
        docker exec "$container" pg_dump -U vault_user forlock | gzip > "$backup_file"
    else
        docker exec forlock-postgres pg_dump -U vault_user forlock | gzip > "$backup_file"
    fi

    local size=$(du -h "$backup_file" | cut -f1)
    echo -e "${GREEN}   Created: $backup_file ($size)${NC}"
}

backup_redis() {
    echo -e "${GREEN}[2/3] Backing up Redis...${NC}"

    local container=$(get_container "redis")
    local backup_file="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"

    if [ "$SWARM_MODE" = true ]; then
        docker exec "$container" redis-cli BGSAVE
        sleep 2
        docker cp "$container:/data/dump.rdb" "$backup_file"
    else
        docker exec forlock-redis redis-cli BGSAVE
        sleep 2
        docker cp forlock-redis:/data/dump.rdb "$backup_file"
    fi

    local size=$(du -h "$backup_file" | cut -f1)
    echo -e "${GREEN}   Created: $backup_file ($size)${NC}"
}

cleanup_old() {
    echo -e "${GREEN}[3/3] Cleaning up old backups (>${RETENTION_DAYS} days)...${NC}"

    local count=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "*.rdb" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

    echo -e "${GREEN}   Removed $count old backups${NC}"
}

upload_s3() {
    local bucket=$1
    echo -e "${GREEN}Uploading to S3: $bucket...${NC}"

    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI not installed${NC}"
        exit 1
    fi

    aws s3 sync "$BACKUP_DIR" "s3://$bucket/forlock-backups/" \
        --exclude "*" \
        --include "postgres_${TIMESTAMP}*" \
        --include "redis_${TIMESTAMP}*"

    echo -e "${GREEN}Upload complete${NC}"
}

# Main
echo ""
echo "Forlock Backup"
echo "=============="
echo ""

if [ "$1" = "--s3" ]; then
    BUCKET=$2
    if [ -z "$BUCKET" ]; then
        echo -e "${RED}Usage: $0 --s3 <bucket-name>${NC}"
        exit 1
    fi
    BACKUP_DIR="/tmp/forlock-backup-$$"
fi

backup_postgres
backup_redis
cleanup_old

if [ "$1" = "--s3" ]; then
    upload_s3 "$BUCKET"
    rm -rf "$BACKUP_DIR"
fi

echo ""
echo -e "${GREEN}Backup complete!${NC}"
echo ""
echo "Backups stored in: $BACKUP_DIR"
echo ""
