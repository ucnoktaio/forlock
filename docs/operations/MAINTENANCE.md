# Forlock Operations & Maintenance Guide

**Document Version**: 1.0
**Last Updated**: 2025-12-30

---

## Table of Contents

1. [Overview](#1-overview)
2. [Maintenance Scripts](#2-maintenance-scripts)
3. [Backup & Restore](#3-backup--restore)
4. [Monitoring & Health Checks](#4-monitoring--health-checks)
5. [Regular Maintenance Schedule](#5-regular-maintenance-schedule)
6. [Certificate Management](#6-certificate-management)
7. [Change Management](#7-change-management)

---

## 1. Overview

This document provides operational procedures for maintaining Forlock in production environments.

### Maintenance Scripts Location
All maintenance scripts are located in `scripts/maintenance/`:

| Script | Description |
|--------|-------------|
| `backup.sh` | Backup database and Redis |
| `restore.sh` | Restore from backup |
| `upgrade.sh` | Upgrade to latest version |
| `logs.sh` | View and export logs |
| `health-check.sh` | Check service health |

---

## 2. Maintenance Scripts

### Backup Script

```bash
# Backup to local directory
./scripts/maintenance/backup.sh

# Backup to custom path
./scripts/maintenance/backup.sh /mnt/backups

# Backup to S3-compatible storage
./scripts/maintenance/backup.sh --s3 my-bucket
```

**Output**:
- PostgreSQL dump: `backups/postgres_YYYYMMDD_HHMMSS.sql.gz`
- Redis snapshot: `backups/redis_YYYYMMDD_HHMMSS.rdb.gz`
- Configuration: `backups/config_YYYYMMDD_HHMMSS.tar.gz`

### Restore Script

```bash
# List available backups
./scripts/maintenance/restore.sh --list

# Restore latest backup
./scripts/maintenance/restore.sh --latest

# Restore specific backup
./scripts/maintenance/restore.sh backups/postgres_20241230_120000.sql.gz
```

### Upgrade Script

```bash
# Upgrade all services to latest
./scripts/maintenance/upgrade.sh

# Upgrade specific service
./scripts/maintenance/upgrade.sh api

# Rollback if issues detected
./scripts/maintenance/upgrade.sh --rollback
```

### Logs Script

```bash
# View all service logs
./scripts/maintenance/logs.sh

# View specific service logs
./scripts/maintenance/logs.sh api

# Show only errors
./scripts/maintenance/logs.sh --errors

# Export logs to file
./scripts/maintenance/logs.sh --export
```

### Health Check Script

```bash
# Run health checks on all services
./scripts/maintenance/health-check.sh
```

**Checks performed**:
- Container status
- API health endpoint
- Database connectivity
- Redis connectivity
- Disk space
- Memory usage

---

## 3. Backup & Restore

### Backup Strategy

| Data Type | Frequency | Retention |
|-----------|-----------|-----------|
| PostgreSQL (Full) | Daily 02:00 UTC | 30 days |
| PostgreSQL (WAL) | Continuous | 7 days |
| Redis (RDB) | Every 15 min | 24 hours |
| Configuration | On change | Git history |
| Secrets | On change | Encrypted offline |

### Manual Backup Commands

**PostgreSQL**:
```bash
# Full backup
docker exec forlock-postgres pg_dump -U postgres -F c -f /tmp/backup.dump forlock
docker cp forlock-postgres:/tmp/backup.dump ./backups/

# Compress
gzip ./backups/backup.dump
```

**Redis**:
```bash
# Trigger save
docker exec forlock-redis redis-cli BGSAVE

# Copy snapshot
docker cp forlock-redis:/data/dump.rdb ./backups/redis_$(date +%Y%m%d).rdb
```

### Restore Commands

**PostgreSQL**:
```bash
# Stop API to prevent writes
docker stop forlock-api

# Restore
gunzip -c backup.dump.gz | docker exec -i forlock-postgres pg_restore \
  -U postgres -d forlock -c -v

# Start API
docker start forlock-api
```

**Redis**:
```bash
docker stop forlock-redis
docker cp redis_backup.rdb forlock-redis:/data/dump.rdb
docker start forlock-redis
```

---

## 4. Monitoring & Health Checks

### Critical Metrics

**Application**:
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| API response time | <200ms p95 | >500ms |
| Failed logins | Monitor | >10/min from same IP |
| Vault unlock rate | >99% | <95% |
| MFA enrollment | >80% | <50% |

**Infrastructure**:
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| CPU usage | <70% | >85% |
| Memory usage | <80% | >90% |
| Disk space | >20% free | <10% free |
| DB connections | <80% pool | >90% pool |

**Security**:
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Blocked IPs | Monitor | Unusual patterns |
| Audit log integrity | 100% | Any failure |
| Certificate expiry | >30 days | <14 days |
| Backup success | 100% | Any failure |

### Health Check Endpoints

```bash
# API health
curl https://your-domain/api/v1/health

# Database connectivity
curl https://your-domain/api/v1/health/db

# Redis connectivity
curl https://your-domain/api/v1/health/redis
```

### Container Health

```bash
# View container status
docker ps

# View resource usage
docker stats

# View specific container logs
docker logs -f forlock-api --tail 100
```

---

## 5. Regular Maintenance Schedule

### Daily
- [ ] Review audit logs for critical events
- [ ] Verify backup success
- [ ] Check disk space

### Weekly
- [ ] Backup verification test
- [ ] Security log review
- [ ] Certificate expiry check

### Monthly
- [ ] DR plan review
- [ ] Incident response plan review
- [ ] Access control audit
- [ ] Vulnerability scan review

### Quarterly
- [ ] DR drill (simulated disaster)
- [ ] Incident response training
- [ ] Security policies review
- [ ] Compliance documentation update

---

## 6. Certificate Management

### Current Setup
- **Encryption**: AES-256-GCM for data-at-rest
- **Certificates**: ECDSA P-256
- **Key Storage**: HashiCorp Vault (optional) or encrypted files

### Certificate Rotation

**When to Rotate**:
- Every 90 days (recommended)
- Immediately if compromise suspected
- On cryptographic weakness discovery

**SSL Certificate Renewal** (Let's Encrypt):
```bash
# Using certbot
certbot renew

# Reload nginx
docker exec forlock-nginx nginx -s reload
```

---

## 7. Change Management

### Pre-Change Checklist

- [ ] Change request ticket created
- [ ] Backup verified (recent + tested)
- [ ] Rollback plan documented
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified

### Post-Change Checklist

- [ ] Change documented in audit log
- [ ] Health checks verified
- [ ] Monitoring alerts reviewed
- [ ] Stakeholders notified (completion)

### Upgrade Procedure

1. **Announce maintenance window**
2. **Create backup**:
   ```bash
   ./scripts/maintenance/backup.sh
   ```
3. **Pull new images**:
   ```bash
   docker compose pull
   ```
4. **Deploy with rolling update**:
   ```bash
   ./scripts/maintenance/upgrade.sh
   ```
5. **Verify health**:
   ```bash
   ./scripts/maintenance/health-check.sh
   ```
6. **Rollback if needed**:
   ```bash
   ./scripts/maintenance/upgrade.sh --rollback
   ```

---

## Troubleshooting

### Common Issues

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| Container not starting | Configuration error | Check `docker logs <container>` |
| Database connection error | PostgreSQL down | `docker restart forlock-postgres` |
| 502 Bad Gateway | API starting | Wait 30s, check API health |
| SSL errors | Certificate expired | Renew certificates |
| High memory usage | Memory leak | Restart API container |
| Slow API response | DB queries | Check slow query log |

### Log Locations

| Service | Log Location |
|---------|--------------|
| API | `docker logs forlock-api` |
| PostgreSQL | `docker logs forlock-postgres` |
| Nginx | `docker logs forlock-nginx` |
| Redis | `docker logs forlock-redis` |
| All logs | `./scripts/maintenance/logs.sh` |

### Emergency Contacts

| Role | Contact |
|------|---------|
| Infrastructure | [Configure contact] |
| Security | [Configure contact] |
| Database | [Configure contact] |
| Vendor Support | [Configure contact] |

---

## Related Documentation

- [Disaster Recovery Plan](DISASTER_RECOVERY.md)
- [Incident Response Playbook](INCIDENT_RESPONSE.md)
- [Deployment Guide](../SINGLE_NODE.md)
