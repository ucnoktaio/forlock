# Forlock Deployment Checklist

Use this checklist to ensure a successful deployment.

---

## Pre-Deployment Requirements

### System Requirements

- [ ] **Operating System**: Ubuntu 22.04+ / Debian 11+ / RHEL 8+
- [ ] **CPU**: 2+ vCPU (4+ recommended)
- [ ] **Memory**: 2GB+ RAM (4GB+ recommended)
- [ ] **Disk**: 20GB+ free space (SSD recommended)

### Software Requirements

- [ ] **Docker**: Version 24.0 or higher
  ```bash
  docker --version
  ```
- [ ] **Docker Compose**: V2 (included in Docker)
  ```bash
  docker compose version
  ```
- [ ] **Git**: For cloning repository
  ```bash
  git --version
  ```

### Network Requirements

- [ ] **Port 80**: Available (HTTP)
- [ ] **Port 443**: Available (HTTPS)
- [ ] **Outbound access**: Docker Hub, GitHub
- [ ] **DNS**: Domain configured (if using custom domain)

### Credentials

- [ ] **Docker Hub token**: Obtained from administrator
  ```bash
  echo "<TOKEN>" | docker login -u ucnokta --password-stdin
  ```

---

## Pre-Flight Check

Run the automated pre-flight check:

```bash
./scripts/preflight-check.sh
```

Expected output: All checks should pass (green) or warn (yellow).

---

## Deployment Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/ucnoktaio/forlock.git
cd forlock
```

- [ ] Repository cloned successfully

### Step 2: Generate Configuration

```bash
cp .env.example .env
./scripts/generate-secrets.sh
```

- [ ] `.env` file created
- [ ] Secrets generated

### Step 3: Configure Domain

Edit `.env` and update:

```bash
DOMAIN=your-domain.com
CORS_ALLOWED_ORIGINS=https://your-domain.com
FIDO2_DOMAIN=your-domain.com
FIDO2_ORIGIN=https://your-domain.com
```

- [ ] Domain configured in `.env`

### Step 4: Deploy

**Single Node:**
```bash
docker compose up -d
```

**Docker Swarm:**
```bash
docker swarm init
./scripts/generate-secrets.sh --swarm
docker stack deploy -c docker-compose.swarm.yml forlock
```

- [ ] Containers started without errors

### Step 5: Verify Deployment

```bash
./scripts/maintenance/health-check.sh
```

- [ ] All services healthy
- [ ] API responding at `/api/health`

---

## Post-Deployment Tasks

### Immediate (Day 1)

- [ ] **Create admin account**: Complete setup wizard at https://your-domain.com
- [ ] **Test login**: Verify authentication works
- [ ] **Configure MFA**: Enable for admin account
- [ ] **Verify SSL**: Certificate valid and HTTPS working

### Within First Week

- [ ] **Configure backups**: Set up automated backups
  ```bash
  # Add to crontab
  0 2 * * * /opt/forlock/scripts/maintenance/backup.sh
  ```
- [ ] **Set up monitoring**: Configure alerting
- [ ] **Test restore**: Verify backup can be restored
- [ ] **Document access**: Record admin credentials securely

### Ongoing

- [ ] **Review logs**: Check for errors weekly
- [ ] **Update regularly**: Pull latest images monthly
- [ ] **Test DR**: Quarterly disaster recovery test
- [ ] **Rotate secrets**: Annual credential rotation

---

## SSL Certificate Setup

### Option A: Let's Encrypt (Recommended)

```bash
docker compose --profile ssl up -d certbot
docker exec forlock-certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d your-domain.com \
  --agree-tos \
  --email admin@your-domain.com
```

- [ ] Certificate obtained
- [ ] Auto-renewal configured

### Option B: Custom Certificate

1. Place files in `./ssl/`:
   - `ssl/fullchain.pem`
   - `ssl/privkey.pem`

2. Update nginx configuration

- [ ] Certificate installed
- [ ] HTTPS verified

---

## Verification Commands

```bash
# Check container status
docker compose ps

# View logs
docker compose logs -f

# Check API health
curl -s http://localhost/api/health | jq

# Check database connectivity
docker exec forlock-postgres pg_isready

# Check Redis
docker exec forlock-redis redis-cli ping
```

---

## Rollback Procedure

If deployment fails:

```bash
# Stop all containers
docker compose down

# Restore from backup (if data was migrated)
./scripts/maintenance/restore.sh --latest

# Restart with previous version
IMAGE_TAG=previous-version docker compose up -d
```

---

## Support

- **Documentation**: [docs/README.md](docs/README.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Issues**: https://github.com/ucnoktaio/forlock/issues
- **Security**: security@ucnokta.io
