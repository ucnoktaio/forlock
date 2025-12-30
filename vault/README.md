# Vault Integration for Forlock

HashiCorp Vault integration for centralized secrets management.

## Quick Start

```bash
# 1. Start Vault
docker compose up -d

# 2. Initialize (first time only)
./scripts/init-vault.sh

# 3. Setup Forlock integration
export VAULT_TOKEN=<root-token-from-init>
./scripts/setup-vault.sh

# 4. Store secrets
./scripts/store-secrets.sh
```

## Directory Structure

```
vault/
├── config/
│   └── vault.hcl           # Vault configuration
├── policies/
│   ├── forlock-api.hcl     # API read-only policy
│   └── forlock-admin.hcl   # Admin full-access policy
├── scripts/
│   ├── init-vault.sh       # Initialize Vault
│   ├── unseal-vault.sh     # Unseal after restart
│   ├── setup-vault.sh      # Configure for Forlock
│   ├── store-secrets.sh    # Store secrets interactively
│   ├── backup-vault.sh     # Backup Raft data
│   └── restore-vault.sh    # Restore from backup
├── docker-compose.yml      # Vault deployment
└── README.md               # This file
```

## Scripts

| Script | Description |
|--------|-------------|
| `init-vault.sh` | Initialize Vault, generate unseal keys and root token |
| `unseal-vault.sh` | Unseal Vault after restart (requires unseal keys) |
| `setup-vault.sh` | Enable secrets engine, create policies, setup AppRole |
| `store-secrets.sh` | Interactively store Forlock secrets |
| `backup-vault.sh` | Create encrypted Raft snapshot |
| `restore-vault.sh` | Restore from snapshot |

## Configuration

### Environment Variables

Add to your `.env.secrets`:

```bash
VAULT__ENABLED=true
VAULT__ADDRESS=http://vault:8200
VAULT__AUTH_METHOD=approle
VAULT__ROLE_ID=<from-setup-vault.sh>
VAULT__SECRET_ID=<from-setup-vault.sh>
VAULT__MOUNT_PATH=forlock
```

### Secrets Stored

| Path | Contents |
|------|----------|
| `forlock/database` | PostgreSQL connection |
| `forlock/redis` | Redis connection |
| `forlock/rabbitmq` | RabbitMQ credentials |
| `forlock/jwt` | JWT signing configuration |

## Documentation

See [Vault Integration Guide](../docs/guides/VAULT_INTEGRATION.md) for detailed documentation.
