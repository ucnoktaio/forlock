#!/bin/bash
#
# Forlock Pre-Deployment Validation Script
#
# Validates all prerequisites before deployment to catch issues early.
# Run this before docker compose up or install.sh
#
# Usage: ./scripts/preflight-check.sh [--fix]
#   --fix    Attempt to fix issues automatically (where possible)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MIN_DOCKER_VERSION="24.0.0"
MIN_DISK_GB=20
REQUIRED_PORTS=(80 443)
INTERNAL_PORTS=(5432 6379 5672 15672)

# Counters
PASS=0
WARN=0
FAIL=0

# Parse arguments
FIX_MODE=false
QUIET=false
for arg in "$@"; do
    case $arg in
        --fix) FIX_MODE=true ;;
        --quiet|-q) QUIET=true ;;
    esac
done

# Helper functions
log_pass() {
    ((PASS++))
    [ "$QUIET" = false ] && echo -e "${GREEN}[PASS]${NC} $1"
}

log_warn() {
    ((WARN++))
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_fail() {
    ((FAIL++))
    echo -e "${RED}[FAIL]${NC} $1"
}

log_info() {
    [ "$QUIET" = false ] && echo -e "${BLUE}[INFO]${NC} $1"
}

version_gte() {
    # Returns 0 if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Forlock Pre-Deployment Validation            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 1. Docker Installation
# ============================================
log_info "Checking Docker..."

if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$DOCKER_VERSION" ]; then
        if version_gte "$DOCKER_VERSION" "$MIN_DOCKER_VERSION"; then
            log_pass "Docker $DOCKER_VERSION installed (>= $MIN_DOCKER_VERSION required)"
        else
            log_fail "Docker $DOCKER_VERSION too old (>= $MIN_DOCKER_VERSION required)"
        fi
    else
        log_fail "Could not determine Docker version"
    fi
else
    log_fail "Docker not installed"
    echo "       Install: https://docs.docker.com/engine/install/"
fi

# ============================================
# 2. Docker Daemon Running
# ============================================
if docker info &> /dev/null; then
    log_pass "Docker daemon is running"
else
    log_fail "Docker daemon is not running"
    echo "       Run: sudo systemctl start docker"
fi

# ============================================
# 3. Docker Compose V2
# ============================================
log_info "Checking Docker Compose..."

if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$COMPOSE_VERSION" ]; then
        log_pass "Docker Compose V2 ($COMPOSE_VERSION) available"
    else
        log_pass "Docker Compose V2 available"
    fi
else
    log_fail "Docker Compose V2 not available"
    echo "       Docker Compose V2 is included in Docker Desktop"
    echo "       For Linux: https://docs.docker.com/compose/install/"
fi

# ============================================
# 4. Git Installation
# ============================================
log_info "Checking Git..."

if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    log_pass "Git $GIT_VERSION installed"
else
    log_warn "Git not installed (required for clone method)"
    echo "       Install: apt install git OR yum install git"
fi

# ============================================
# 5. Disk Space
# ============================================
log_info "Checking disk space..."

AVAILABLE_GB=$(df -BG . 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}')
if [ -n "$AVAILABLE_GB" ] && [ "$AVAILABLE_GB" -ge "$MIN_DISK_GB" ]; then
    log_pass "Disk space: ${AVAILABLE_GB}GB available (>= ${MIN_DISK_GB}GB required)"
else
    log_fail "Insufficient disk space: ${AVAILABLE_GB:-?}GB available (>= ${MIN_DISK_GB}GB required)"
fi

# ============================================
# 6. Memory
# ============================================
log_info "Checking memory..."

if [ -f /proc/meminfo ]; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    if [ "$TOTAL_MEM_GB" -ge 2 ]; then
        log_pass "Memory: ${TOTAL_MEM_GB}GB total (>= 2GB required)"
    else
        log_warn "Memory: ${TOTAL_MEM_GB}GB total (2GB+ recommended)"
    fi
elif command -v sysctl &> /dev/null; then
    # macOS
    TOTAL_MEM_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
    TOTAL_MEM_GB=$((TOTAL_MEM_BYTES / 1024 / 1024 / 1024))
    log_pass "Memory: ${TOTAL_MEM_GB}GB total"
else
    log_warn "Could not determine memory size"
fi

# ============================================
# 7. Port Availability (External)
# ============================================
log_info "Checking external ports..."

check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":$port " && return 1
    elif command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ":$port " && return 1
    elif command -v lsof &> /dev/null; then
        lsof -iTCP:$port -sTCP:LISTEN &>/dev/null && return 1
    fi
    return 0
}

for port in "${REQUIRED_PORTS[@]}"; do
    if check_port "$port"; then
        log_pass "Port $port is available"
    else
        log_fail "Port $port is already in use"
        echo "       Check: lsof -i :$port"
    fi
done

# ============================================
# 8. Network Connectivity
# ============================================
log_info "Checking network connectivity..."

check_connectivity() {
    local host=$1
    local desc=$2
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 5 "$host" > /dev/null 2>&1; then
            log_pass "Can reach $desc"
            return 0
        fi
    elif command -v wget &> /dev/null; then
        if wget -q --timeout=5 --spider "$host" 2>/dev/null; then
            log_pass "Can reach $desc"
            return 0
        fi
    fi
    log_warn "Cannot reach $desc (may be firewall)"
    return 1
}

check_connectivity "https://hub.docker.com" "Docker Hub"
check_connectivity "https://github.com" "GitHub"

# ============================================
# 9. Environment File
# ============================================
log_info "Checking configuration files..."

if [ -f ".env" ]; then
    log_pass ".env file exists"

    # Check required variables
    REQUIRED_VARS=(
        "DOMAIN"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "JWT_SECRET_KEY"
    )

    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${var}=" .env 2>/dev/null; then
            VALUE=$(grep "^${var}=" .env | cut -d'=' -f2-)
            if [ -n "$VALUE" ] && [ "$VALUE" != "" ] && [ "$VALUE" != "CHANGE_ME" ]; then
                log_pass "  $var is configured"
            else
                log_fail "  $var is empty or placeholder"
            fi
        else
            log_fail "  $var is missing"
        fi
    done
elif [ -f ".env.example" ]; then
    log_warn ".env file not found (run: cp .env.example .env && ./scripts/generate-secrets.sh)"
else
    log_warn "No .env or .env.example found"
fi

# ============================================
# 10. Docker Hub Authentication (Optional)
# ============================================
log_info "Checking Docker Hub authentication..."

if docker info 2>/dev/null | grep -q "Username:"; then
    DOCKER_USER=$(docker info 2>/dev/null | grep "Username:" | awk '{print $2}')
    log_pass "Logged in to Docker Hub as: $DOCKER_USER"
else
    log_warn "Not logged in to Docker Hub"
    echo "       Run: echo '<TOKEN>' | docker login -u ucnokta --password-stdin"
fi

# ============================================
# 11. Existing Containers
# ============================================
log_info "Checking for existing Forlock containers..."

EXISTING=$(docker ps -a --filter "name=forlock" --format "{{.Names}}" 2>/dev/null | wc -l)
if [ "$EXISTING" -gt 0 ]; then
    log_warn "Found $EXISTING existing Forlock container(s)"
    echo "       Existing deployment detected. Use upgrade.sh or remove first."
else
    log_pass "No existing Forlock containers"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "═══════════════════════════════════════════════════"
echo -e "Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"
echo "═══════════════════════════════════════════════════"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Pre-flight check FAILED${NC}"
    echo "Please resolve the issues above before deploying."
    exit 1
elif [ $WARN -gt 0 ]; then
    echo -e "${YELLOW}Pre-flight check PASSED with warnings${NC}"
    echo "Deployment may proceed, but review warnings above."
    exit 0
else
    echo -e "${GREEN}Pre-flight check PASSED${NC}"
    echo "Ready to deploy!"
    exit 0
fi
