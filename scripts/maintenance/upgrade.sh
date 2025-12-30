#!/bin/bash
#
# Forlock Upgrade Script
#
# Usage:
#   ./upgrade.sh              # Upgrade all services
#   ./upgrade.sh api          # Upgrade only API
#   ./upgrade.sh --rollback   # Rollback to previous version
#

set -e

# Resolve script directory for reliable path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

SERVICE="${1:-all}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running in Swarm mode
SWARM_MODE=false
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    SWARM_MODE=true
fi

backup_before_upgrade() {
    echo -e "${BLUE}[1/4] Creating backup before upgrade...${NC}"
    "$SCRIPT_DIR/backup.sh" "$PROJECT_ROOT/backups/pre-upgrade-$(date +%Y%m%d_%H%M%S)"
}

pull_images() {
    echo -e "${BLUE}[2/4] Pulling latest images...${NC}"

    if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "api" ]; then
        docker pull ucnokta/forlock-api:latest
    fi

    if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "frontend" ]; then
        docker pull ucnokta/forlock-frontend:latest
    fi

    if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "nginx" ]; then
        docker pull ucnokta/forlock-nginx:latest
    fi
}

upgrade_compose() {
    echo -e "${BLUE}[3/4] Upgrading services (Compose mode)...${NC}"

    if [ "$SERVICE" = "all" ]; then
        docker compose up -d --no-deps api frontend nginx
    else
        docker compose up -d --no-deps "$SERVICE"
    fi
}

upgrade_swarm() {
    echo -e "${BLUE}[3/4] Upgrading services (Swarm mode)...${NC}"

    if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "api" ]; then
        echo "  Updating API..."
        docker service update --image ucnokta/forlock-api:latest \
            --update-parallelism 1 \
            --update-delay 30s \
            forlock_api
    fi

    if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "frontend" ]; then
        echo "  Updating Frontend..."
        docker service update --image ucnokta/forlock-frontend:latest \
            --update-parallelism 1 \
            --update-delay 10s \
            forlock_frontend
    fi

    if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "nginx" ]; then
        echo "  Updating Nginx..."
        docker service update --image ucnokta/forlock-nginx:latest \
            forlock_nginx
    fi
}

verify_upgrade() {
    echo -e "${BLUE}[4/4] Verifying upgrade...${NC}"
    sleep 10
    "$SCRIPT_DIR/health-check.sh"
}

rollback_compose() {
    echo -e "${YELLOW}Rolling back (Compose mode)...${NC}"

    # Find latest pre-upgrade backup
    local latest_backup=$(ls -t "$PROJECT_ROOT/backups/pre-upgrade-"*/postgres_*.sql.gz 2>/dev/null | head -1)

    if [ -n "$latest_backup" ]; then
        echo "Found backup: $latest_backup"
        "$SCRIPT_DIR/restore.sh" "$latest_backup"
    else
        echo -e "${RED}No pre-upgrade backup found${NC}"
    fi
}

rollback_swarm() {
    echo -e "${YELLOW}Rolling back (Swarm mode)...${NC}"

    if [ "$SERVICE" = "all" ]; then
        docker service rollback forlock_api
        docker service rollback forlock_frontend
        docker service rollback forlock_nginx
    else
        docker service rollback "forlock_$SERVICE"
    fi
}

# Main
echo ""
echo "Forlock Upgrade"
echo "==============="
echo ""

case "$1" in
    --rollback)
        if [ "$SWARM_MODE" = true ]; then
            rollback_swarm
        else
            rollback_compose
        fi
        ;;
    *)
        backup_before_upgrade
        pull_images

        if [ "$SWARM_MODE" = true ]; then
            upgrade_swarm
        else
            upgrade_compose
        fi

        verify_upgrade

        echo ""
        echo -e "${GREEN}Upgrade complete!${NC}"
        ;;
esac
