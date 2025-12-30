# Forlock Deployment Package

Self-hosted password vault for enterprises.

---

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB | 8 GB |
| Disk | 20 GB SSD | 50 GB SSD |
| OS | Ubuntu 22.04 | Ubuntu 24.04 |
| Docker | 24.0+ | Latest |

### Scaling by User Count

| Users | CPU | RAM | Disk | Deployment |
|-------|-----|-----|------|------------|
| < 500 | 4 vCPU | 8 GB | 50 GB | Single Node |
| 1K-5K | 8 vCPU | 32 GB | 200 GB | Single Node |
| 5K+ | See [Swarm Guide](docs/SWARM.md) | | | Docker Swarm |

### Before You Start

Have these ready:
- [ ] Docker Hub access token (from administrator)
- [ ] Domain name (e.g., `vault.yourcompany.com`)
- [ ] SSL certificate OR email for Let's Encrypt
- [ ] DNS configured to point to server IP

---

## Deployment Steps

### Step 1: Server Setup

```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker && systemctl start docker

# Verify Docker version (must be 24.0+)
docker --version

# Configure firewall
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw enable
```

### Step 2: Docker Hub Login

```bash
echo "<ACCESS_TOKEN>" | docker login -u ucnokta --password-stdin
```

### Step 3: Clone Repository

```bash
git clone https://github.com/ucnoktaio/forlock.git /opt/forlock
cd /opt/forlock
```

### Step 4: Generate Secrets

```bash
./scripts/generate-secrets.sh
```

This creates `.env` with secure random passwords for:
- PostgreSQL, Redis, RabbitMQ
- JWT signing key
- Vault master encryption key

### Step 5: Configure Domain

Edit `.env` and update these values:

```bash
nano .env
```

```env
# Change these to your domain
DOMAIN=vault.yourcompany.com
CORS_ALLOWED_ORIGINS=https://vault.yourcompany.com
FIDO2_DOMAIN=vault.yourcompany.com
FIDO2_ORIGIN=https://vault.yourcompany.com
```

### Step 6: Deploy

```bash
docker compose pull
docker compose up -d
```

Wait 60 seconds for all services to start.

### Step 7: Verify Deployment

```bash
# Check all containers are running
docker ps --format "table {{.Names}}\t{{.Status}}"

# Expected output: All containers show "Up" and "healthy"
# forlock-nginx      Up (healthy)
# forlock-api        Up (healthy)
# forlock-frontend   Up
# forlock-postgres   Up (healthy)
# forlock-redis      Up (healthy)
# forlock-rabbitmq   Up (healthy)

# Run health check
./scripts/maintenance/health-check.sh

# Test API endpoint
curl -s http://localhost/api/health
```

### Step 8: SSL Certificate

#### Option A: Let's Encrypt (Recommended)

```bash
# Start certbot
docker compose --profile ssl up -d certbot

# Generate certificate
docker exec forlock-certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d vault.yourcompany.com \
  --agree-tos --email admin@yourcompany.com

# Restart nginx to load certificate
docker restart forlock-nginx
```

#### Option B: Custom Certificate

```bash
# Copy your certificate files
cp your-cert.crt ssl/server.crt
cp your-key.key ssl/server.key

# Restart nginx
docker restart forlock-nginx
```

### Step 9: Create Admin User

1. Open `https://vault.yourcompany.com` in browser
2. Complete the setup wizard
3. Save the recovery key securely

---

## Deployment Complete

Your Forlock instance is now running at `https://vault.yourcompany.com`

---

## Alternative Deployments

| Scenario | Use Case | Guide |
|----------|----------|-------|
| Docker Swarm | 5K+ users, HA required | [Swarm Guide](docs/SWARM.md) |
| Kubernetes | Enterprise/Cloud | [K8s Guide](docs/KUBERNETES.md) |

---

## Maintenance

### Daily Operations

```bash
# Check health
./scripts/maintenance/health-check.sh

# View logs
./scripts/maintenance/logs.sh

# Backup (run daily via cron)
./scripts/maintenance/backup.sh
```

### Upgrades

```bash
# Upgrade all services
./scripts/maintenance/upgrade.sh

# Rollback if needed
./scripts/maintenance/upgrade.sh --rollback
```

See [Single Node Guide](docs/SINGLE_NODE.md) for detailed maintenance procedures.

---

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| 502 Bad Gateway | API starting | Wait 60 seconds |
| Container not starting | Check logs | `docker logs forlock-api` |
| Database connection error | PostgreSQL not ready | `docker logs forlock-postgres` |
| SSL errors | Certificate issue | Check `ssl/` directory |

---

## Security Checklist

- [ ] Firewall only allows 22, 80, 443
- [ ] SSL certificate installed
- [ ] `.env` file permissions set to 600
- [ ] Daily backups configured
- [ ] Admin password is strong

---

## Support

- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/ucnoktaio/forlock/issues)
- Security: security@ucnokta.io

---

## License

Proprietary - Contact for licensing information.
