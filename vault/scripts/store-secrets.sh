#!/bin/bash
# Store Forlock secrets in Vault
# Run this after setup-vault.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_CONTAINER="${VAULT_CONTAINER:-forlock-vault}"

echo -e "${GREEN}=== Store Forlock Secrets in Vault ===${NC}"
echo ""

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

# Prompt for secrets
echo -e "${YELLOW}Enter the following secrets (input will be hidden):${NC}"
echo ""

# Database
echo "PostgreSQL Configuration:"
read -p "  Host [postgres]: " DB_HOST
DB_HOST=${DB_HOST:-postgres}
read -p "  Port [5432]: " DB_PORT
DB_PORT=${DB_PORT:-5432}
read -p "  Database [forlock]: " DB_NAME
DB_NAME=${DB_NAME:-forlock}
read -p "  Username [forlock]: " DB_USER
DB_USER=${DB_USER:-forlock}
read -s -p "  Password: " DB_PASS
echo ""

# Redis
echo ""
echo "Redis Configuration:"
read -p "  Host [redis]: " REDIS_HOST
REDIS_HOST=${REDIS_HOST:-redis}
read -p "  Port [6379]: " REDIS_PORT
REDIS_PORT=${REDIS_PORT:-6379}
read -s -p "  Password: " REDIS_PASS
echo ""

# RabbitMQ
echo ""
echo "RabbitMQ Configuration:"
read -p "  Host [rabbitmq]: " RABBITMQ_HOST
RABBITMQ_HOST=${RABBITMQ_HOST:-rabbitmq}
read -p "  Port [5672]: " RABBITMQ_PORT
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
read -p "  Username [forlock]: " RABBITMQ_USER
RABBITMQ_USER=${RABBITMQ_USER:-forlock}
read -s -p "  Password: " RABBITMQ_PASS
echo ""

# JWT
echo ""
echo "JWT Configuration:"
read -s -p "  Secret Key (min 32 chars): " JWT_SECRET
echo ""
read -p "  Issuer [forlock]: " JWT_ISSUER
JWT_ISSUER=${JWT_ISSUER:-forlock}
read -p "  Audience [forlock-api]: " JWT_AUDIENCE
JWT_AUDIENCE=${JWT_AUDIENCE:-forlock-api}
read -p "  Expiration Minutes [60]: " JWT_EXPIRATION
JWT_EXPIRATION=${JWT_EXPIRATION:-60}

echo ""
echo -e "${YELLOW}Storing secrets in Vault...${NC}"

# Store database secrets
vault_cmd kv put forlock/database \
    host="$DB_HOST" \
    port="$DB_PORT" \
    database="$DB_NAME" \
    username="$DB_USER" \
    password="$DB_PASS"
echo -e "${GREEN}  Stored: forlock/database${NC}"

# Store Redis secrets
vault_cmd kv put forlock/redis \
    host="$REDIS_HOST" \
    port="$REDIS_PORT" \
    password="$REDIS_PASS"
echo -e "${GREEN}  Stored: forlock/redis${NC}"

# Store RabbitMQ secrets
vault_cmd kv put forlock/rabbitmq \
    host="$RABBITMQ_HOST" \
    port="$RABBITMQ_PORT" \
    username="$RABBITMQ_USER" \
    password="$RABBITMQ_PASS"
echo -e "${GREEN}  Stored: forlock/rabbitmq${NC}"

# Store JWT secrets
vault_cmd kv put forlock/jwt \
    secret_key="$JWT_SECRET" \
    issuer="$JWT_ISSUER" \
    audience="$JWT_AUDIENCE" \
    expiration_minutes="$JWT_EXPIRATION"
echo -e "${GREEN}  Stored: forlock/jwt${NC}"

echo ""
echo -e "${GREEN}=== All secrets stored successfully ===${NC}"
echo ""
echo -e "${YELLOW}Verify with:${NC}"
echo "  vault kv get forlock/database"
echo "  vault kv get forlock/redis"
echo "  vault kv get forlock/rabbitmq"
echo "  vault kv get forlock/jwt"
echo ""
