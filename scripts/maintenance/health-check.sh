#!/bin/bash
#
# Forlock Health Check Script
#
# Usage:
#   ./health-check.sh [--json]
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

JSON_OUTPUT=false

if [ "$1" = "--json" ]; then
    JSON_OUTPUT=true
fi

# Check if we're in swarm mode
SWARM_MODE=false
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    SWARM_MODE=true
fi

check_container() {
    local name=$1
    local status
    local health

    if [ "$SWARM_MODE" = true ]; then
        # Swarm mode - check service
        status=$(docker service ls --filter "name=forlock_$name" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
    else
        # Compose mode - check container
        status=$(docker inspect --format='{{.State.Status}}' "forlock-$name" 2>/dev/null || echo "not_found")
        health=$(docker inspect --format='{{.State.Health.Status}}' "forlock-$name" 2>/dev/null || echo "none")
    fi

    if [ "$JSON_OUTPUT" = true ]; then
        echo "\"$name\": {\"status\": \"$status\", \"health\": \"$health\"}"
    else
        if [ "$status" = "running" ] || [[ "$status" == *"/"* && "$status" != "0/0" ]]; then
            if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
                echo -e "${GREEN}[OK]${NC} $name - $status"
            else
                echo -e "${YELLOW}[WARN]${NC} $name - $status (health: $health)"
            fi
        else
            echo -e "${RED}[FAIL]${NC} $name - $status"
        fi
    fi
}

check_api_health() {
    local response
    local http_code

    # Try to get API health
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health 2>/dev/null || echo "000")

    if [ "$JSON_OUTPUT" = true ]; then
        echo "\"api_endpoint\": {\"http_code\": $response}"
    else
        if [ "$response" = "200" ]; then
            echo -e "${GREEN}[OK]${NC} API Health - HTTP $response"
        elif [ "$response" = "000" ]; then
            echo -e "${RED}[FAIL]${NC} API Health - Connection refused"
        else
            echo -e "${YELLOW}[WARN]${NC} API Health - HTTP $response"
        fi
    fi
}

check_disk_space() {
    local usage
    usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

    if [ "$JSON_OUTPUT" = true ]; then
        echo "\"disk_usage\": $usage"
    else
        if [ "$usage" -lt 80 ]; then
            echo -e "${GREEN}[OK]${NC} Disk Usage - ${usage}%"
        elif [ "$usage" -lt 90 ]; then
            echo -e "${YELLOW}[WARN]${NC} Disk Usage - ${usage}%"
        else
            echo -e "${RED}[FAIL]${NC} Disk Usage - ${usage}%"
        fi
    fi
}

check_memory() {
    local usage
    usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')

    if [ "$JSON_OUTPUT" = true ]; then
        echo "\"memory_usage\": $usage"
    else
        if [ "$usage" -lt 80 ]; then
            echo -e "${GREEN}[OK]${NC} Memory Usage - ${usage}%"
        elif [ "$usage" -lt 90 ]; then
            echo -e "${YELLOW}[WARN]${NC} Memory Usage - ${usage}%"
        else
            echo -e "${RED}[FAIL]${NC} Memory Usage - ${usage}%"
        fi
    fi
}

# Main
if [ "$JSON_OUTPUT" = true ]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"swarm_mode\": $SWARM_MODE,"
    echo "  \"containers\": {"
    check_container "postgres"
    echo ","
    check_container "redis"
    echo ","
    check_container "rabbitmq"
    echo ","
    check_container "api"
    echo ","
    check_container "frontend"
    echo ","
    check_container "nginx"
    echo "  },"
    check_api_health
    echo ","
    check_disk_space
    echo ","
    check_memory
    echo "}"
else
    echo ""
    echo "Forlock Health Check"
    echo "===================="
    echo ""
    echo "Containers:"
    check_container "postgres"
    check_container "redis"
    check_container "rabbitmq"
    check_container "api"
    check_container "frontend"
    check_container "nginx"
    echo ""
    echo "Endpoints:"
    check_api_health
    echo ""
    echo "System:"
    check_disk_space
    check_memory
    echo ""
fi
