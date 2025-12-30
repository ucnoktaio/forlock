# Forlock Deployment Package

Self-hosted password vault deployment for enterprises.

## Quick Start (< 5 minutes)

### Option 1: One-Liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/ucnoktaio/forlock/main/scripts/install.sh | \
  DOCKER_TOKEN=<your-token> bash
```

### Option 2: Manual Install

```bash
# 1. Docker Hub login
echo "<TOKEN>" | docker login -u ucnokta --password-stdin

# 2. Clone and configure
git clone https://github.com/ucnoktaio/forlock.git
cd forlock
./scripts/generate-secrets.sh

# 3. Deploy
docker compose up -d
```

### Option 3: Docker Swarm (HA)

```bash
# Initialize swarm
docker swarm init --advertise-addr <MANAGER_IP>

# Generate secrets
./scripts/generate-secrets.sh --swarm

# Deploy stack
docker stack deploy -c docker-compose.swarm.yml forlock
```

### Option 4: Kubernetes

```bash
# Apply all manifests
./scripts/generate-secrets.sh --k8s
kubectl apply -f k8s/
```

---

## Prerequisites

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 2 GB | 4 GB |
| Disk | 20 GB | 50 GB SSD |
| Docker | 24.0+ | Latest |
| OS | Ubuntu 22.04 | Ubuntu 24.04 |

### Scaling by User Count

| Users | CPU | RAM | Disk | Deployment |
|-------|-----|-----|------|------------|
| < 500 | 4 vCPU | 8 GB | 50 GB | Single Node |
| 1K-5K | 8 vCPU | 32 GB | 200 GB | Single Node |
| 5K-10K | 16 vCPU | 64 GB | 500 GB | Docker Swarm |
| 10K+ | 32+ vCPU | 128+ GB | 1+ TB | Swarm/K8s |

See [Resource Sizing Guide](docs/SINGLE_NODE.md#resource-sizing-guide) for details.

---

## Docker Hub Authentication

Request access token from administrator, then:

```bash
echo "<ACCESS_TOKEN>" | docker login -u ucnokta --password-stdin
```

### Images

| Image | Description |
|-------|-------------|
| `ucnokta/forlock-api` | Backend API (.NET 9) |
| `ucnokta/forlock-frontend` | Web UI (React) |
| `ucnokta/forlock-nginx` | Reverse proxy |

---

## Deployment Scenarios

| Scenario | Use Case | File |
|----------|----------|------|
| Single Node | Dev/Small teams | `docker-compose.yml` |
| Docker Swarm | Production HA | `docker-compose.swarm.yml` |
| Kubernetes | Enterprise/Cloud | `k8s/*.yaml` |

See detailed guides:
- [Single Node Guide](docs/SINGLE_NODE.md) - Up to 5K users
- [Docker Swarm Guide](docs/SWARM.md) - 5K-20K+ users with HA
- [Kubernetes Guide](docs/KUBERNETES.md) - Enterprise/Cloud native

---

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
nano .env
```

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `vault.company.com` |
| `POSTGRES_PASSWORD` | DB password | Auto-generated |
| `JWT_SECRET_KEY` | Auth signing key | Auto-generated |
| `VAULT_MASTER_KEY` | Encryption key | Auto-generated |

### Auto-Generate Secrets

```bash
./scripts/generate-secrets.sh
```

---

## Post-Installation

### Verify Deployment

```bash
# Check health
curl -s http://localhost/api/health | jq .

# Check containers
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Create Admin User

Navigate to `https://your-domain.com` and complete the setup wizard.

### SSL Certificate (Let's Encrypt)

```bash
docker compose --profile ssl up -d certbot
docker exec forlock-certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d your-domain.com \
  --agree-tos --email admin@your-domain.com
```

---

## Maintenance Scripts

Located in `scripts/maintenance/`:

| Script | Description |
|--------|-------------|
| `backup.sh` | Backup database and Redis |
| `restore.sh` | Restore from backup |
| `upgrade.sh` | Upgrade to latest version |
| `logs.sh` | View and export logs |
| `health-check.sh` | Check service health |

### Backup

```bash
# Backup to ./backups/
./scripts/maintenance/backup.sh

# Backup to custom path
./scripts/maintenance/backup.sh /mnt/backups

# Backup to S3
./scripts/maintenance/backup.sh --s3 my-bucket
```

### Restore

```bash
# List available backups
./scripts/maintenance/restore.sh --list

# Restore latest
./scripts/maintenance/restore.sh --latest

# Restore specific backup
./scripts/maintenance/restore.sh backups/postgres_20241230_120000.sql.gz
```

### Upgrade

```bash
# Upgrade all services
./scripts/maintenance/upgrade.sh

# Upgrade specific service
./scripts/maintenance/upgrade.sh api

# Rollback if needed
./scripts/maintenance/upgrade.sh --rollback
```

### Logs

```bash
# All services
./scripts/maintenance/logs.sh

# Specific service
./scripts/maintenance/logs.sh api

# Show only errors
./scripts/maintenance/logs.sh --errors

# Export logs to file
./scripts/maintenance/logs.sh --export
```

### Health Check

```bash
./scripts/maintenance/health-check.sh
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Container not starting | Check `docker logs <container>` |
| Database connection error | Verify PostgreSQL is healthy |
| 502 Bad Gateway | API container may be starting |
| SSL errors | Check certificate paths |

---

## HashiCorp Vault Integration (Optional)

For enhanced secrets management, integrate with HashiCorp Vault:

```bash
# 1. Start Vault
cd vault && docker compose up -d

# 2. Initialize and setup
./vault/scripts/init-vault.sh
export VAULT_TOKEN=<root-token>
./vault/scripts/setup-vault.sh

# 3. Store secrets in Vault
./vault/scripts/store-secrets.sh
```

See [Vault Integration Guide](docs/guides/VAULT_INTEGRATION.md) for details.

---

## Security

- **Firewall**: Only expose ports 80, 443
- **Secrets**: Never commit `.env` file
- **Vault**: Use HashiCorp Vault for production secrets
- **Updates**: Regularly pull latest images
- **Backups**: Daily database backups recommended

---

## Support

- **Issues**: [GitHub Issues](https://github.com/ucnoktaio/forlock/issues)
- **Security**: security@ucnokta.io

---

## License

Proprietary - Contact for licensing information.
