#!/bin/bash
#
# Forlock Secret Generator
#
# Usage:
#   ./generate-secrets.sh           # Create .env file
#   ./generate-secrets.sh --swarm   # Create Docker Swarm secrets
#   ./generate-secrets.sh --k8s     # Create Kubernetes secrets
#   ./generate-secrets.sh --print   # Print to stdout only
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
MODE="env"
PRINT_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --swarm)
            MODE="swarm"
            shift
            ;;
        --k8s|--kubernetes)
            MODE="k8s"
            shift
            ;;
        --print)
            PRINT_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--swarm|--k8s|--print]"
            echo ""
            echo "Options:"
            echo "  --swarm    Create Docker Swarm secrets"
            echo "  --k8s      Create Kubernetes secrets"
            echo "  --print    Print secrets to stdout only"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Generate secure random string
generate_secret() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d '/+=' | head -c "$length"
}

# Generate secrets
POSTGRES_PASSWORD=$(generate_secret 24)
REDIS_PASSWORD=$(generate_secret 24)
RABBITMQ_PASSWORD=$(generate_secret 24)
JWT_SECRET=$(openssl rand -base64 48)
VAULT_MASTER_KEY=$(openssl rand -base64 32)
SYSTEM_MASTER_KEY=$(openssl rand -base64 32)

echo -e "${BLUE}Forlock Secret Generator${NC}"
echo "========================="
echo ""

case $MODE in
    env)
        if [ "$PRINT_ONLY" = true ]; then
            echo "# Forlock Secrets - Generated $(date)"
            echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
            echo "REDIS_PASSWORD=$REDIS_PASSWORD"
            echo "RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD"
            echo "JWT_SECRET_KEY=$JWT_SECRET"
            echo "VAULT_MASTER_KEY=$VAULT_MASTER_KEY"
            echo "SYSTEM_MASTER_KEY=$SYSTEM_MASTER_KEY"
        else
            ENV_FILE="$PROJECT_DIR/.env"

            if [ -f "$ENV_FILE" ]; then
                echo -e "${YELLOW}Warning: .env file exists. Creating .env.new${NC}"
                ENV_FILE="$PROJECT_DIR/.env.new"
            fi

            cat > "$ENV_FILE" << EOF
# Forlock Environment Configuration
# Generated: $(date)
# WARNING: Keep this file secure!

# ==========================================
# Domain Configuration
# ==========================================
DOMAIN=localhost
CORS_ALLOWED_ORIGINS=https://localhost
FIDO2_DOMAIN=localhost
FIDO2_SERVER_NAME=Forlock
FIDO2_ORIGIN=https://localhost

# ==========================================
# Database
# ==========================================
POSTGRES_DB=forlock
POSTGRES_USER=vault_user
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# ==========================================
# Redis
# ==========================================
REDIS_PASSWORD=$REDIS_PASSWORD

# ==========================================
# RabbitMQ
# ==========================================
RABBITMQ_USER=forlock
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD

# ==========================================
# JWT Authentication
# ==========================================
JWT_SECRET_KEY=$JWT_SECRET
JWT_ISSUER=forlock-api
JWT_AUDIENCE=forlock-clients
JWT_EXPIRATION_MINUTES=480

# ==========================================
# Encryption Keys (CRITICAL - BACKUP THESE!)
# ==========================================
VAULT_MASTER_KEY=$VAULT_MASTER_KEY
SYSTEM_MASTER_KEY=$SYSTEM_MASTER_KEY

# ==========================================
# Image Configuration
# ==========================================
IMAGE_TAG=latest

# ==========================================
# Logging
# ==========================================
LOG_LEVEL=Information
EOF

            chmod 600 "$ENV_FILE"
            echo -e "${GREEN}Created: $ENV_FILE${NC}"
            echo ""
            echo -e "${YELLOW}IMPORTANT: Backup VAULT_MASTER_KEY and SYSTEM_MASTER_KEY securely!${NC}"
            echo -e "${YELLOW}Loss of these keys = Loss of all encrypted data${NC}"
        fi
        ;;

    swarm)
        echo -e "${BLUE}Creating Docker Swarm secrets...${NC}"
        echo ""

        if [ "$PRINT_ONLY" = true ]; then
            echo "# Run these commands to create Docker Swarm secrets:"
            echo "echo '$POSTGRES_PASSWORD' | docker secret create postgres_password -"
            echo "echo '$REDIS_PASSWORD' | docker secret create redis_password -"
            echo "echo '$RABBITMQ_PASSWORD' | docker secret create rabbitmq_password -"
            echo "echo '$JWT_SECRET' | docker secret create jwt_secret -"
            echo "echo '$VAULT_MASTER_KEY' | docker secret create vault_master_key -"
            echo "echo '$SYSTEM_MASTER_KEY' | docker secret create system_master_key -"
        else
            # Check if swarm is initialized
            if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
                echo -e "${RED}Error: Docker Swarm is not initialized${NC}"
                echo "Run: docker swarm init --advertise-addr <IP>"
                exit 1
            fi

            # Create secrets
            echo "$POSTGRES_PASSWORD" | docker secret create postgres_password - 2>/dev/null && \
                echo -e "${GREEN}Created: postgres_password${NC}" || \
                echo -e "${YELLOW}Exists: postgres_password${NC}"

            echo "$REDIS_PASSWORD" | docker secret create redis_password - 2>/dev/null && \
                echo -e "${GREEN}Created: redis_password${NC}" || \
                echo -e "${YELLOW}Exists: redis_password${NC}"

            echo "$RABBITMQ_PASSWORD" | docker secret create rabbitmq_password - 2>/dev/null && \
                echo -e "${GREEN}Created: rabbitmq_password${NC}" || \
                echo -e "${YELLOW}Exists: rabbitmq_password${NC}"

            echo "$JWT_SECRET" | docker secret create jwt_secret - 2>/dev/null && \
                echo -e "${GREEN}Created: jwt_secret${NC}" || \
                echo -e "${YELLOW}Exists: jwt_secret${NC}"

            echo "$VAULT_MASTER_KEY" | docker secret create vault_master_key - 2>/dev/null && \
                echo -e "${GREEN}Created: vault_master_key${NC}" || \
                echo -e "${YELLOW}Exists: vault_master_key${NC}"

            echo "$SYSTEM_MASTER_KEY" | docker secret create system_master_key - 2>/dev/null && \
                echo -e "${GREEN}Created: system_master_key${NC}" || \
                echo -e "${YELLOW}Exists: system_master_key${NC}"

            echo ""
            echo -e "${GREEN}All secrets created!${NC}"
            echo ""
            echo "Deploy with: docker stack deploy -c docker-compose.swarm.yml forlock"
        fi
        ;;

    k8s)
        echo -e "${BLUE}Creating Kubernetes secrets...${NC}"
        echo ""

        if [ "$PRINT_ONLY" = true ]; then
            echo "# Run this command to create Kubernetes secrets:"
            cat << EOF
kubectl create secret generic forlock-secrets \\
  --from-literal=postgres-password='$POSTGRES_PASSWORD' \\
  --from-literal=redis-password='$REDIS_PASSWORD' \\
  --from-literal=rabbitmq-password='$RABBITMQ_PASSWORD' \\
  --from-literal=jwt-secret='$JWT_SECRET' \\
  --from-literal=vault-master-key='$VAULT_MASTER_KEY' \\
  --from-literal=system-master-key='$SYSTEM_MASTER_KEY' \\
  -n forlock
EOF
        else
            # Check kubectl
            if ! command -v kubectl &> /dev/null; then
                echo -e "${RED}Error: kubectl not found${NC}"
                exit 1
            fi

            # Create namespace
            kubectl create namespace forlock 2>/dev/null && \
                echo -e "${GREEN}Created namespace: forlock${NC}" || \
                echo -e "${YELLOW}Namespace exists: forlock${NC}"

            # Create secrets
            kubectl create secret generic forlock-secrets \
                --from-literal=postgres-password="$POSTGRES_PASSWORD" \
                --from-literal=redis-password="$REDIS_PASSWORD" \
                --from-literal=rabbitmq-password="$RABBITMQ_PASSWORD" \
                --from-literal=jwt-secret="$JWT_SECRET" \
                --from-literal=vault-master-key="$VAULT_MASTER_KEY" \
                --from-literal=system-master-key="$SYSTEM_MASTER_KEY" \
                -n forlock 2>/dev/null && \
                echo -e "${GREEN}Created: forlock-secrets${NC}" || \
                echo -e "${YELLOW}Exists: forlock-secrets${NC}"

            echo ""
            echo -e "${GREEN}Secrets created!${NC}"
            echo ""
            echo "Deploy with: kubectl apply -f k8s/"
        fi
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
