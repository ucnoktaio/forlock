# HashiCorp Vault Integration Guide

**Document Version**: 1.0
**Last Updated**: 2025-12-30

---

## Overview

Forlock can integrate with HashiCorp Vault for enhanced secrets management. This guide covers deployment, configuration, and integration of Vault with Forlock.

### Benefits of Vault Integration

| Feature | Description |
|---------|-------------|
| **Centralized Secrets** | Store database credentials, API keys, TLS certificates in Vault |
| **Dynamic Secrets** | Auto-rotating database credentials |
| **Audit Logging** | Complete audit trail of secret access |
| **HSM Support** | Hardware Security Module integration |
| **Access Policies** | Fine-grained access control for secrets |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FORLOCK + VAULT                           │
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │   Forlock    │────────►│    Vault     │                     │
│  │     API      │  Token  │   Server     │                     │
│  └──────────────┘         └──────┬───────┘                     │
│         │                        │                              │
│         │                        │                              │
│         ▼                        ▼                              │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │  PostgreSQL  │         │   Storage    │                     │
│  │   (secrets   │         │  (Consul/    │                     │
│  │   from Vault)│         │   File/Raft) │                     │
│  └──────────────┘         └──────────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Deployment Options

### Option 1: Standalone Vault (Recommended for Production)

Dedicated Vault cluster with high availability.

### Option 2: Integrated Vault

Vault running alongside Forlock in the same Docker network.

---

## Quick Start

### 1. Deploy Vault

```bash
cd /path/to/forlock

# Start Vault
docker compose -f vault/docker-compose.yml up -d

# Check status
docker exec forlock-vault vault status
```

### 2. Initialize Vault (First Time Only)

```bash
# Initialize Vault (save the keys securely!)
docker exec forlock-vault vault operator init \
  -key-shares=5 \
  -key-threshold=3

# Output:
# Unseal Key 1: xxxxx
# Unseal Key 2: xxxxx
# Unseal Key 3: xxxxx
# Unseal Key 4: xxxxx
# Unseal Key 5: xxxxx
# Initial Root Token: hvs.xxxxx

# IMPORTANT: Store these keys securely!
# - Use a secure password manager
# - Split keys among trusted administrators
# - Never store all keys in the same location
```

### 3. Unseal Vault

```bash
# Unseal with 3 of 5 keys
docker exec -it forlock-vault vault operator unseal
# Enter key 1...
docker exec -it forlock-vault vault operator unseal
# Enter key 2...
docker exec -it forlock-vault vault operator unseal
# Enter key 3...

# Verify unsealed
docker exec forlock-vault vault status
```

### 4. Configure Forlock Integration

```bash
# Run the setup script
./vault/scripts/setup-vault.sh
```

---

## Production Configuration

### vault/docker-compose.yml

```yaml
version: '3.8'

services:
  vault:
    image: hashicorp/vault:1.15
    container_name: forlock-vault
    restart: unless-stopped
    ports:
      - "127.0.0.1:8200:8200"  # Only localhost access
    volumes:
      - vault-data:/vault/data
      - ./config:/vault/config:ro
      - ./policies:/vault/policies:ro
    environment:
      VAULT_ADDR: "http://127.0.0.1:8200"
      VAULT_API_ADDR: "http://127.0.0.1:8200"
    cap_add:
      - IPC_LOCK
    command: server -config=/vault/config/vault.hcl
    networks:
      - forlock-network
    healthcheck:
      test: ["CMD", "vault", "status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  vault-data:
    driver: local

networks:
  forlock-network:
    external: true
```

### vault/config/vault.hcl

```hcl
ui = true
disable_mlock = false
cluster_name = "forlock-vault"

# Storage backend (Raft for HA)
storage "raft" {
  path = "/vault/data"
  node_id = "vault-1"
}

# Listener configuration
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = false
  tls_cert_file = "/vault/config/tls/vault.crt"
  tls_key_file  = "/vault/config/tls/vault.key"
}

# API address
api_addr = "https://vault.your-domain.com:8200"
cluster_addr = "https://vault.your-domain.com:8201"

# Telemetry
telemetry {
  disable_hostname = true
  prometheus_retention_time = "12h"
}

# Audit logging
# Enabled via CLI after initialization
```

---

## Secrets Configuration

### Enable Secrets Engines

```bash
# Login to Vault
export VAULT_ADDR="https://vault.your-domain.com:8200"
vault login

# Enable KV secrets engine for Forlock
vault secrets enable -path=forlock kv-v2

# Enable database secrets engine (optional - for dynamic credentials)
vault secrets enable database
```

### Store Forlock Secrets

```bash
# Store database credentials
vault kv put forlock/database \
  host="postgres" \
  port="5432" \
  username="forlock" \
  password="your-secure-password" \
  database="forlock"

# Store Redis credentials
vault kv put forlock/redis \
  host="redis" \
  port="6379" \
  password="your-redis-password"

# Store RabbitMQ credentials
vault kv put forlock/rabbitmq \
  host="rabbitmq" \
  port="5672" \
  username="forlock" \
  password="your-rabbitmq-password"

# Store JWT signing key
vault kv put forlock/jwt \
  secret_key="your-256-bit-secret-key" \
  issuer="forlock" \
  audience="forlock-api"

# Store encryption keys
vault kv put forlock/encryption \
  master_key="your-master-encryption-key"
```

### Dynamic Database Credentials (Advanced)

```bash
# Configure PostgreSQL connection
vault write database/config/forlock-postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="forlock-app" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/forlock?sslmode=require" \
  username="vault-admin" \
  password="vault-admin-password"

# Create role for dynamic credentials
vault write database/roles/forlock-app \
  db_name=forlock-postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

---

## Access Policies

### vault/policies/forlock-api.hcl

```hcl
# Forlock API Policy
# Read access to all forlock secrets

# KV secrets
path "forlock/data/*" {
  capabilities = ["read", "list"]
}

path "forlock/metadata/*" {
  capabilities = ["read", "list"]
}

# Dynamic database credentials (if enabled)
path "database/creds/forlock-app" {
  capabilities = ["read"]
}

# Token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

### Apply Policies

```bash
# Create the policy
vault policy write forlock-api /vault/policies/forlock-api.hcl

# Create AppRole for Forlock API
vault auth enable approle

vault write auth/approle/role/forlock-api \
  secret_id_ttl=0 \
  token_ttl=1h \
  token_max_ttl=4h \
  token_policies="forlock-api"

# Get Role ID and Secret ID
vault read auth/approle/role/forlock-api/role-id
vault write -f auth/approle/role/forlock-api/secret-id
```

---

## Forlock Configuration

### Environment Variables

```bash
# .env or .env.secrets
VAULT__ENABLED=true
VAULT__ADDRESS=https://vault.your-domain.com:8200
VAULT__AUTH_METHOD=approle
VAULT__ROLE_ID=your-role-id
VAULT__SECRET_ID=your-secret-id
VAULT__MOUNT_PATH=forlock
VAULT__TLS_SKIP_VERIFY=false
```

### Docker Compose Integration

```yaml
# docker-compose.yml
services:
  api:
    # ... other config ...
    environment:
      - VAULT__ENABLED=true
      - VAULT__ADDRESS=http://vault:8200
      - VAULT__AUTH_METHOD=approle
      - VAULT__ROLE_ID=${VAULT_ROLE_ID}
      - VAULT__SECRET_ID=${VAULT_SECRET_ID}
    depends_on:
      vault:
        condition: service_healthy
```

---

## High Availability Setup

### Multi-Node Raft Cluster

```yaml
# vault-node1.hcl
storage "raft" {
  path = "/vault/data"
  node_id = "vault-1"

  retry_join {
    leader_api_addr = "https://vault-2:8200"
  }
  retry_join {
    leader_api_addr = "https://vault-3:8200"
  }
}
```

### Auto-Unseal with Cloud KMS

```hcl
# AWS KMS
seal "awskms" {
  region     = "eu-central-1"
  kms_key_id = "alias/vault-unseal-key"
}

# Azure Key Vault
seal "azurekeyvault" {
  tenant_id  = "your-tenant-id"
  vault_name = "your-keyvault-name"
  key_name   = "vault-unseal-key"
}

# Google Cloud KMS
seal "gcpckms" {
  project     = "your-project"
  region      = "europe-west1"
  key_ring    = "vault-keyring"
  crypto_key  = "vault-unseal-key"
}
```

---

## Backup & Recovery

### Backup Vault Data

```bash
#!/bin/bash
# vault/scripts/backup-vault.sh

BACKUP_DIR="/backups/vault"
DATE=$(date +%Y%m%d_%H%M%S)

# Create Raft snapshot
docker exec forlock-vault vault operator raft snapshot save \
  /tmp/vault-snapshot-${DATE}.snap

# Copy snapshot from container
docker cp forlock-vault:/tmp/vault-snapshot-${DATE}.snap \
  ${BACKUP_DIR}/vault-snapshot-${DATE}.snap

# Encrypt the backup
gpg --symmetric --cipher-algo AES256 \
  -o ${BACKUP_DIR}/vault-snapshot-${DATE}.snap.gpg \
  ${BACKUP_DIR}/vault-snapshot-${DATE}.snap

# Remove unencrypted snapshot
rm ${BACKUP_DIR}/vault-snapshot-${DATE}.snap

echo "Vault backup completed: vault-snapshot-${DATE}.snap.gpg"
```

### Restore Vault Data

```bash
#!/bin/bash
# vault/scripts/restore-vault.sh

SNAPSHOT_FILE=$1

if [ -z "$SNAPSHOT_FILE" ]; then
  echo "Usage: ./restore-vault.sh <snapshot-file>"
  exit 1
fi

# Decrypt if encrypted
if [[ "$SNAPSHOT_FILE" == *.gpg ]]; then
  gpg --decrypt -o /tmp/vault-snapshot.snap "$SNAPSHOT_FILE"
  SNAPSHOT_FILE="/tmp/vault-snapshot.snap"
fi

# Copy to container
docker cp "$SNAPSHOT_FILE" forlock-vault:/tmp/restore-snapshot.snap

# Restore snapshot
docker exec forlock-vault vault operator raft snapshot restore \
  -force /tmp/restore-snapshot.snap

echo "Vault restore completed"
```

---

## Monitoring

### Health Check Endpoint

```bash
# Check Vault health
curl -s https://vault.your-domain.com:8200/v1/sys/health | jq

# Response codes:
# 200 - initialized, unsealed, active
# 429 - unsealed, standby
# 472 - disaster recovery mode replication secondary and target
# 473 - performance standby
# 501 - not initialized
# 503 - sealed
```

### Prometheus Metrics

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'vault'
    metrics_path: '/v1/sys/metrics'
    params:
      format: ['prometheus']
    bearer_token: 'your-vault-token'
    static_configs:
      - targets: ['vault:8200']
```

### Key Metrics to Monitor

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `vault_core_unsealed` | Seal status | Alert if 0 |
| `vault_token_count` | Active tokens | > 10000 |
| `vault_expire_leases` | Expiring leases | Monitor trends |
| `vault_audit_log_response` | Audit log latency | > 100ms |

---

## Security Best Practices

### 1. Unseal Key Management

- Split keys among 5 trusted administrators
- Require 3 of 5 keys to unseal (Shamir's Secret Sharing)
- Store keys in separate secure locations
- Consider auto-unseal with Cloud KMS for production

### 2. Token Management

- Use short-lived tokens (1-4 hours)
- Enable token renewal for long-running applications
- Use AppRole for machine authentication
- Rotate Secret IDs regularly

### 3. Network Security

- Enable TLS for all Vault communications
- Restrict network access to Vault ports
- Use internal network for Forlock-Vault communication
- Never expose Vault directly to the internet

### 4. Audit Logging

```bash
# Enable file audit
vault audit enable file file_path=/vault/logs/audit.log

# Enable syslog audit
vault audit enable syslog tag="vault" facility="AUTH"
```

### 5. Regular Maintenance

- Rotate root token after initial setup
- Review and update policies quarterly
- Monitor seal status
- Test backup and restore procedures

---

## Troubleshooting

### Vault is Sealed

```bash
# Check seal status
vault status

# Unseal with keys
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
```

### Cannot Connect to Vault

```bash
# Check Vault is running
docker ps | grep vault

# Check network connectivity
docker exec forlock-api curl -s http://vault:8200/v1/sys/health

# Check logs
docker logs forlock-vault --tail 100
```

### Permission Denied

```bash
# Check token policies
vault token lookup

# Verify policy allows access
vault policy read forlock-api

# Test secret access
vault kv get forlock/database
```

### Token Expired

```bash
# Renew token (if renewable)
vault token renew

# Generate new token
vault token create -policy=forlock-api -ttl=4h
```

---

## Related Documents

- [Security Architecture](../security/ARCHITECTURE.md)
- [Encryption & Key Management](../security/ENCRYPTION.md)
- [Disaster Recovery](../operations/DISASTER_RECOVERY.md)
