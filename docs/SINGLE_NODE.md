# Single Node Deployment Guide

Deploy Forlock on a single server for development or small teams.

## Prerequisites

| Component | Requirement |
|-----------|-------------|
| OS | Ubuntu 22.04/24.04, Debian 12, CentOS 9 |
| CPU | 2 vCPU minimum |
| RAM | 2 GB minimum |
| Disk | 20 GB SSD |
| Docker | 24.0+ with Compose V2 |

## Quick Start

### 1. Server Setup

```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Install Docker Compose plugin
apt install docker-compose-plugin -y

# Configure firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### 2. Docker Hub Login

```bash
echo "<ACCESS_TOKEN>" | docker login -u ucnokta --password-stdin
```

### 3. Clone Repository

```bash
git clone https://github.com/ucnokta/forlock-deploy.git /opt/forlock
cd /opt/forlock
```

### 4. Generate Secrets

```bash
./scripts/generate-secrets.sh
```

### 5. Configure Domain

Edit `.env` file:

```bash
nano .env
```

Update these values:
```env
DOMAIN=vault.yourcompany.com
CORS_ALLOWED_ORIGINS=https://vault.yourcompany.com
FIDO2_DOMAIN=vault.yourcompany.com
FIDO2_ORIGIN=https://vault.yourcompany.com
```

### 6. Deploy

```bash
docker compose pull
docker compose up -d
```

### 7. Verify

```bash
docker compose ps
./scripts/health-check.sh
```

---

## SSL Certificate

### Option A: Self-Signed (Testing)

```bash
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/server.key \
  -out ssl/server.crt \
  -subj "/CN=vault.yourcompany.com"
```

### Option B: Let's Encrypt (Production)

```bash
# Start with certbot profile
docker compose --profile ssl up -d

# Generate certificate
docker exec forlock-certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d vault.yourcompany.com \
  --agree-tos --email admin@yourcompany.com

# Restart nginx
docker restart forlock-nginx
```

---

## Maintenance

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker logs forlock-api --tail 100
```

### Restart Services

```bash
# Single service
docker restart forlock-api

# All services
docker compose restart
```

### Update Images

```bash
docker compose pull
docker compose up -d
```

### Backup Database

```bash
docker exec forlock-postgres pg_dump -U vault_user forlock | \
  gzip > backup_$(date +%Y%m%d).sql.gz
```

### Restore Database

```bash
gunzip -c backup_20241230.sql.gz | \
  docker exec -i forlock-postgres psql -U vault_user forlock
```

---

## Resource Limits

Default limits in `docker-compose.yml`:

| Service | CPU | Memory |
|---------|-----|--------|
| PostgreSQL | 1 core | 512 MB |
| Redis | 0.5 core | 256 MB |
| RabbitMQ | 0.5 core | 256 MB |
| API | 2 cores | 1 GB |
| Frontend | 0.5 core | 128 MB |
| Nginx | 0.5 core | 128 MB |

Adjust in `docker-compose.yml` if needed:

```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 2G
```

---

## Troubleshooting

### Container won't start

```bash
docker logs forlock-api --tail 200
docker inspect forlock-api | jq '.[0].State'
```

### Database connection error

```bash
docker exec forlock-postgres pg_isready -U vault_user
docker logs forlock-postgres --tail 50
```

### 502 Bad Gateway

API is still starting. Wait 60 seconds or check:

```bash
docker logs forlock-api -f
```

### Out of disk space

```bash
df -h
docker system prune -a
```
