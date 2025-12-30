# Forlock Troubleshooting Guide

Quick reference for resolving common deployment and operational issues.

---

## Quick Diagnostics

Run these commands first:

```bash
# Overall status
docker compose ps

# Recent logs (all services)
docker compose logs --tail=50

# Health check
./scripts/maintenance/health-check.sh
```

---

## Installation Issues

### Docker Not Found

**Symptom**: `docker: command not found`

**Solution**:
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Docker Compose V2 Not Found

**Symptom**: `docker: 'compose' is not a docker command`

**Solution**:
```bash
# Docker Compose V2 is included in Docker Desktop
# For Linux servers:
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

### Permission Denied

**Symptom**: `permission denied while trying to connect to the Docker daemon`

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then verify
docker ps
```

### Port Already in Use

**Symptom**: `bind: address already in use`

**Solution**:
```bash
# Find what's using the port
sudo lsof -i :80
sudo lsof -i :443

# Stop the conflicting service
sudo systemctl stop nginx  # or apache2

# Or change Forlock ports in .env
NGINX_HTTP_PORT=8080
NGINX_HTTPS_PORT=8443
```

---

## Startup Issues

### Container Won't Start

**Symptom**: Container exits immediately or restarts repeatedly

**Diagnosis**:
```bash
# Check exit code
docker compose ps

# View logs
docker logs forlock-api --tail=100
docker logs forlock-postgres --tail=100
```

**Common Causes**:

| Exit Code | Meaning | Solution |
|-----------|---------|----------|
| 0 | Normal exit | Check if command completed |
| 1 | Application error | Check application logs |
| 137 | Out of memory (OOM) | Increase memory limits |
| 139 | Segmentation fault | Check for corrupted images |

### Database Connection Failed

**Symptom**: `connection refused` or `password authentication failed`

**Diagnosis**:
```bash
# Is PostgreSQL running?
docker compose ps postgres

# Can we connect?
docker exec forlock-postgres pg_isready

# Check logs
docker logs forlock-postgres --tail=50
```

**Solutions**:

1. **PostgreSQL not ready**: Wait 30 seconds, it needs time to initialize
   ```bash
   sleep 30 && docker compose restart api
   ```

2. **Password mismatch**: Regenerate secrets
   ```bash
   docker compose down -v  # WARNING: Deletes data
   ./scripts/generate-secrets.sh
   docker compose up -d
   ```

3. **Corrupted data**: Restore from backup
   ```bash
   ./scripts/maintenance/restore.sh --latest
   ```

### Redis Connection Failed

**Symptom**: `NOAUTH Authentication required` or `connection refused`

**Diagnosis**:
```bash
# Check Redis status
docker exec forlock-redis redis-cli ping
# Should return: PONG

# With authentication
docker exec forlock-redis redis-cli -a $REDIS_PASSWORD ping
```

**Solution**:
```bash
# Restart Redis
docker compose restart redis

# If password issue, check .env
grep REDIS_PASSWORD .env
```

### RabbitMQ Connection Failed

**Symptom**: `connection refused` to port 5672

**Diagnosis**:
```bash
# Check RabbitMQ status
docker exec forlock-rabbitmq rabbitmqctl status

# Check management UI
curl -u guest:guest http://localhost:15672/api/overview
```

**Solution**:
```bash
# Restart RabbitMQ
docker compose restart rabbitmq

# Check credentials in .env
grep RABBITMQ .env
```

---

## Runtime Issues

### 502 Bad Gateway

**Symptom**: Nginx returns 502 error

**Causes**:
1. API container still starting (wait 30-60 seconds)
2. API crashed
3. Memory exhausted

**Diagnosis**:
```bash
# Check if API is running
docker compose ps api

# Check API logs
docker logs forlock-api --tail=100

# Check memory
docker stats --no-stream
```

**Solutions**:
```bash
# Restart API
docker compose restart api

# If OOM, increase memory limit in docker-compose.yml
# deploy.resources.limits.memory: "2G"
```

### 504 Gateway Timeout

**Symptom**: Requests timeout after 60 seconds

**Causes**:
1. Database query slow
2. API processing slow
3. Network issue

**Solutions**:
```bash
# Check API response time
time curl -s http://localhost/api/health

# Check database performance
docker exec forlock-postgres psql -U forlock -c "SELECT 1"

# Increase timeout in nginx (if needed)
```

### SSL Certificate Issues

**Symptom**: `SSL_ERROR_*` or certificate warnings

**Diagnosis**:
```bash
# Check certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Check expiry
echo | openssl s_client -connect your-domain.com:443 2>/dev/null | openssl x509 -noout -dates
```

**Solutions**:

1. **Expired certificate**: Renew with Let's Encrypt
   ```bash
   docker exec forlock-certbot certbot renew
   docker compose restart nginx
   ```

2. **Wrong domain**: Update certificate
   ```bash
   docker exec forlock-certbot certbot certonly \
     --webroot -w /var/www/certbot \
     -d correct-domain.com
   ```

### Slow Performance

**Symptom**: Pages load slowly, API responses delayed

**Diagnosis**:
```bash
# Check resource usage
docker stats

# Check disk I/O
iostat -x 1 5

# Check database size
docker exec forlock-postgres psql -U forlock -c "SELECT pg_size_pretty(pg_database_size('forlock'))"
```

**Solutions**:
```bash
# Vacuum database
docker exec forlock-postgres psql -U forlock -c "VACUUM ANALYZE"

# Restart services
docker compose restart

# Increase resources in docker-compose.yml
```

---

## Data Issues

### Database Corruption

**Symptom**: PostgreSQL won't start, data errors

**Recovery**:
```bash
# Stop everything
docker compose down

# Restore from backup
./scripts/maintenance/restore.sh --latest

# Start services
docker compose up -d
```

### Lost Data After Restart

**Symptom**: Data missing after container restart

**Cause**: Volume not configured correctly

**Prevention**:
```bash
# Verify volumes exist
docker volume ls | grep forlock

# Check volume mount
docker inspect forlock-postgres | grep -A5 Mounts
```

### Backup Failed

**Symptom**: Backup script errors

**Diagnosis**:
```bash
# Check disk space
df -h

# Run backup manually with verbose
./scripts/maintenance/backup.sh 2>&1 | tee backup.log
```

**Solutions**:
```bash
# Free disk space
docker system prune -f

# Check backup directory permissions
ls -la ./backups/
```

---

## Network Issues

### Cannot Pull Images

**Symptom**: `error pulling image` or timeout

**Diagnosis**:
```bash
# Test Docker Hub connectivity
curl -s https://hub.docker.com/v2/ | head

# Check Docker login
docker info | grep Username
```

**Solutions**:
```bash
# Re-login to Docker Hub
echo "$DOCKER_TOKEN" | docker login -u ucnokta --password-stdin

# Check proxy settings
cat /etc/docker/daemon.json
```

### Containers Can't Communicate

**Symptom**: Services can't reach each other

**Diagnosis**:
```bash
# Check network
docker network ls | grep forlock

# Test connectivity from API to PostgreSQL
docker exec forlock-api ping -c 2 postgres
```

**Solution**:
```bash
# Recreate network
docker compose down
docker network rm forlock_default
docker compose up -d
```

---

## Logs and Debugging

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f api

# Last N lines
docker compose logs --tail=100 api

# Since timestamp
docker compose logs --since="2024-01-01T00:00:00" api
```

### Export Logs

```bash
# Export to file
docker compose logs > forlock-logs-$(date +%Y%m%d).txt

# Use maintenance script
./scripts/maintenance/logs.sh --export
```

### Enable Debug Mode

```bash
# Edit .env
ASPNETCORE_ENVIRONMENT=Development
LOG_LEVEL=Debug

# Restart
docker compose restart api
```

---

## Getting Help

If you can't resolve the issue:

1. **Collect diagnostics**:
   ```bash
   ./scripts/maintenance/health-check.sh --json > health.json
   docker compose logs > logs.txt
   docker compose ps > status.txt
   ```

2. **Check documentation**:
   - [Deployment Guide](docs/SINGLE_NODE.md)
   - [Operations Guide](docs/operations/MAINTENANCE.md)

3. **Contact support**:
   - GitHub Issues: https://github.com/ucnoktaio/forlock/issues
   - Security issues: security@ucnokta.io
