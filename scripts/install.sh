#!/bin/bash
#
# Forlock One-Line Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ucnokta/forlock-deploy/main/scripts/install.sh | \
#     DOCKER_TOKEN=<token> bash
#
# Environment Variables:
#   DOCKER_TOKEN    - Docker Hub access token (required)
#   DOCKER_USER     - Docker Hub username (default: ucnokta)
#   INSTALL_DIR     - Installation directory (default: /opt/forlock)
#   DOMAIN          - Domain name (default: localhost)
#   MODE            - Deployment mode: single, swarm (default: single)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DOCKER_USER="${DOCKER_USER:-ucnokta}"
INSTALL_DIR="${INSTALL_DIR:-/opt/forlock}"
DOMAIN="${DOMAIN:-localhost}"
MODE="${MODE:-single}"
REPO_URL="https://github.com/ucnokta/forlock-deploy.git"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Forlock Deployment Installer     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check Docker token
if [ -z "$DOCKER_TOKEN" ]; then
    echo -e "${RED}Error: DOCKER_TOKEN environment variable is required${NC}"
    echo ""
    echo "Usage:"
    echo "  curl -fsSL <url> | DOCKER_TOKEN=<token> bash"
    exit 1
fi

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Warning: Not running as root. Some operations may fail.${NC}"
fi

# Step 1: Check/Install Docker
echo -e "${BLUE}[1/5] Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+')
    echo -e "${GREEN}Docker found: $DOCKER_VERSION${NC}"
else
    echo -e "${YELLOW}Docker not found. Installing...${NC}"

    # Install Docker
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    elif [ -f /etc/redhat-release ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        echo -e "${RED}Unsupported OS. Please install Docker manually.${NC}"
        exit 1
    fi

    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}Docker installed successfully${NC}"
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose V2 not found${NC}"
    exit 1
fi

# Step 2: Docker Hub Login
echo ""
echo -e "${BLUE}[2/5] Logging in to Docker Hub...${NC}"
echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin
echo -e "${GREEN}Logged in as: $DOCKER_USER${NC}"

# Step 3: Clone/Download repository
echo ""
echo -e "${BLUE}[3/5] Setting up installation directory...${NC}"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Directory exists: $INSTALL_DIR${NC}"
    echo -e "${YELLOW}Pulling latest changes...${NC}"
    cd "$INSTALL_DIR"
    git pull origin main 2>/dev/null || true
else
    echo "Cloning repository to $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

chmod +x scripts/*.sh

# Step 4: Generate secrets
echo ""
echo -e "${BLUE}[4/5] Generating secrets...${NC}"

if [ -f ".env" ]; then
    echo -e "${YELLOW}.env file exists. Skipping secret generation.${NC}"
else
    ./scripts/generate-secrets.sh

    # Update domain
    if [ "$DOMAIN" != "localhost" ]; then
        sed -i "s/DOMAIN=localhost/DOMAIN=$DOMAIN/g" .env
        sed -i "s|CORS_ALLOWED_ORIGINS=https://localhost|CORS_ALLOWED_ORIGINS=https://$DOMAIN|g" .env
        sed -i "s/FIDO2_DOMAIN=localhost/FIDO2_DOMAIN=$DOMAIN/g" .env
        sed -i "s|FIDO2_ORIGIN=https://localhost|FIDO2_ORIGIN=https://$DOMAIN|g" .env
        echo -e "${GREEN}Updated domain to: $DOMAIN${NC}"
    fi
fi

# Step 5: Deploy
echo ""
echo -e "${BLUE}[5/5] Deploying Forlock...${NC}"

case $MODE in
    single)
        echo "Mode: Single Node"
        docker compose pull
        docker compose up -d
        ;;
    swarm)
        echo "Mode: Docker Swarm"
        if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
            echo "Initializing Swarm..."
            docker swarm init
        fi
        ./scripts/generate-secrets.sh --swarm
        docker stack deploy -c docker-compose.swarm.yml forlock
        ;;
    *)
        echo -e "${RED}Unknown mode: $MODE${NC}"
        exit 1
        ;;
esac

# Wait for services
echo ""
echo -e "${BLUE}Waiting for services to start...${NC}"
sleep 10

# Health check
echo ""
echo -e "${BLUE}Checking health...${NC}"
./scripts/health-check.sh || true

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation Complete!            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "Access Forlock at: ${BLUE}https://$DOMAIN${NC}"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f          # View logs"
echo "  docker compose ps               # Check status"
echo "  ./scripts/health-check.sh       # Health check"
echo ""
echo -e "${YELLOW}IMPORTANT: Backup your .env file securely!${NC}"
echo ""
