# Forlock Disaster Recovery Plan (DRP)

**Document Version**: 1.0
**Last Updated**: 2025-12-30
**Owner**: Infrastructure & Security Team
**Review Frequency**: Quarterly
**Compliance Standards**: ISO 27001:2022 A.17, NIST SP 800-34 Rev. 1, SOC 2 CC9.1

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Recovery Objectives](#2-recovery-objectives)
3. [System Architecture Overview](#3-system-architecture-overview)
4. [Backup Strategy](#4-backup-strategy)
5. [Recovery Procedures](#5-recovery-procedures)
6. [Roles & Responsibilities](#6-roles--responsibilities)
7. [Communication Plan](#7-communication-plan)
8. [Testing & Maintenance](#8-testing--maintenance)
9. [Appendix](#9-appendix)

---

## 1. Executive Summary

### Purpose
This Disaster Recovery Plan (DRP) establishes procedures to recover Forlock's critical IT systems and data in the event of a disaster, ensuring business continuity and minimizing downtime.

### Scope
This plan covers:
- Production infrastructure
- Database systems (PostgreSQL)
- Cache systems (Redis)
- Application services (API, Frontend, Nginx)
- Message queue (RabbitMQ)
- Logging infrastructure (Graylog)
- Secrets management (HashiCorp Vault integration)

### Disaster Scenarios Covered
- Hardware failure (server crash, disk failure)
- Data corruption (database corruption, file system errors)
- Security incidents (ransomware, data breach, DDoS)
- Natural disasters (data center outage, network failure)
- Human error (accidental deletion, misconfiguration)
- Software failures (application bugs, dependency issues)

---

## 2. Recovery Objectives

### Recovery Time Objective (RTO)
**Target: 4 hours** - Maximum acceptable downtime for critical services

| Service | RTO | Priority |
|---------|-----|----------|
| API (Authentication) | 1 hour | Critical |
| API (Vault Operations) | 2 hours | Critical |
| Database (PostgreSQL) | 1 hour | Critical |
| Cache (Redis) | 30 minutes | High |
| Frontend | 2 hours | High |
| RabbitMQ | 4 hours | Medium |
| Graylog (Logging) | 8 hours | Low |

### Recovery Point Objective (RPO)
**Target: 1 hour** - Maximum acceptable data loss

| Data Type | RPO | Backup Frequency |
|-----------|-----|------------------|
| User Data (PostgreSQL) | 1 hour | Continuous WAL + Hourly snapshots |
| Session Data (Redis) | 15 minutes | RDB snapshots every 15 min |
| Audit Logs | 5 minutes | Real-time replication |
| Configuration Files | 0 (Git-tracked) | On commit |
| Secrets | 0 (Vault-backed) | On change |

### Maximum Tolerable Downtime (MTD)
**24 hours** - Beyond this, business viability is threatened

---

## 3. System Architecture Overview

### Production Environment

#### Infrastructure
- **Cloud Provider**: [Your cloud provider]
- **OS**: Ubuntu 24.04 LTS
- **Deployment**: Docker Compose / Docker Swarm / Kubernetes

#### Container Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    Nginx Reverse Proxy                   │
│                  (Port 80/443 - Public)                  │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐ ┌────────▼───────┐ ┌────────▼───────┐
│   Frontend     │ │   API Backend  │ │   RabbitMQ     │
│  (React/Vite)  │ │   (.NET 9)     │ │  (Messaging)   │
│   Port: 80     │ │  Port: 8080    │ │  Port: 5672    │
└────────────────┘ └────────┬───────┘ └────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐ ┌────────▼───────┐ ┌────────▼───────┐
│  PostgreSQL    │ │     Redis      │ │    Graylog     │
│  (Database)    │ │    (Cache)     │ │   (Logging)    │
│   Port: 5432   │ │   Port: 6379   │ │  Port: 12201   │
└────────────────┘ └────────────────┘ └────────────────┘
```

#### Critical Data Locations
| Data Type | Storage Location | Backup Location |
|-----------|-----------------|-----------------|
| PostgreSQL Data | Docker volume | `/backups/postgres/` |
| Redis Data | Docker volume | `/backups/redis/` |
| Application Logs | `/var/log/forlock/` | Graylog + `/backups/logs/` |
| Configuration | Git repository | Remote repository |
| Secrets | `.env.secrets` + Vault | Encrypted backup (offline) |
| SSL Certificates | `/etc/nginx/ssl/` | `/backups/ssl/` |

---

## 4. Backup Strategy

### 4.1 PostgreSQL Database Backups

#### Full Database Backups (Daily)
- **Schedule**: Daily at 02:00 AM UTC
- **Retention**: 30 days (daily), 12 months (monthly)
- **Tool**: `pg_dump` (custom format)

**Backup Command**:
```bash
# Using the provided maintenance script
./scripts/maintenance/backup.sh

# Or manual backup
docker exec forlock-postgres pg_dump \
  -U ${POSTGRES_USER} \
  -F c \
  -b \
  -v \
  -f /tmp/backup.dump \
  forlock
```

#### Continuous Backups (WAL Archiving)
- **Schedule**: Continuous (every WAL segment - ~16MB)
- **Retention**: 7 days
- **Tool**: PostgreSQL WAL archiving

**PostgreSQL Configuration** (`postgresql.conf`):
```ini
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /backups/postgres/wal/%f && cp %p /backups/postgres/wal/%f'
archive_timeout = 300  # 5 minutes
```

### 4.2 Redis Backups

#### RDB Snapshots
- **Schedule**: Every 15 minutes
- **Retention**: 24 hours (15-min), 7 days (hourly)
- **Tool**: Redis RDB persistence

**Redis Configuration**:
```ini
save 900 1      # Save after 15 minutes if 1 key changed
save 300 10     # Save after 5 minutes if 10 keys changed
save 60 10000   # Save after 1 minute if 10000 keys changed
rdbcompression yes
rdbchecksum yes
```

### 4.3 Configuration Backups

#### Git Repository Backup
- **Primary**: Remote Git repository
- **Secondary**: Mirror repository (optional)
- **Frequency**: On every commit

#### Secrets Backup
**CRITICAL**: Secrets must be backed up separately and encrypted

```bash
# Encrypt secrets with GPG
gpg --symmetric --cipher-algo AES256 .env.secrets

# Store in secure offline location
# - Encrypted USB drive
# - Password manager (1Password, Bitwarden)
# - Encrypted cloud storage (separate from production)
```

### 4.4 Off-Site Backup Storage

#### Cloud Backup (Recommended)
Using the provided backup script:
```bash
# Backup to S3-compatible storage
./scripts/maintenance/backup.sh --s3 your-bucket-name
```

**Provider Options**:
- AWS S3 (with Glacier for long-term)
- Backblaze B2 (cost-effective)
- Wasabi (S3-compatible)

---

## 5. Recovery Procedures

### 5.1 Complete System Failure Recovery

**Scenario**: Production server is completely lost
**RTO**: 4 hours

#### Phase 1: Infrastructure Provisioning (30 minutes)

1. **Provision new server** with your cloud provider
2. **Configure firewall**:
   ```bash
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```
3. **Install Docker & Docker Compose**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   apt-get install docker-compose-plugin -y
   ```

#### Phase 2: Application Deployment (1 hour)

4. **Deploy using the deployment package**:
   ```bash
   # Extract deployment package
   tar -xzf forlock-deploy.tar.gz
   cd forlock-deploy

   # Configure environment
   cp .env.example .env
   # Edit .env with your settings

   # Restore secrets
   gpg --decrypt .env.secrets.gpg > .env.secrets

   # Deploy
   docker compose up -d
   ```

#### Phase 3: Database Recovery (1.5 hours)

5. **Restore PostgreSQL database**:
   ```bash
   # Using the restore script
   ./scripts/maintenance/restore.sh --latest

   # Or manual restore
   docker exec -i forlock-postgres pg_restore \
     -U postgres \
     -d forlock \
     -c \
     -v \
     < /backups/postgres/latest.dump
   ```

6. **Restore Redis data**:
   ```bash
   docker stop forlock-redis
   docker cp /backups/redis/latest.rdb forlock-redis:/data/dump.rdb
   docker start forlock-redis
   ```

#### Phase 4: Verification & Go-Live (1 hour)

7. **Verify services**:
   ```bash
   # Check container health
   docker ps

   # Test API endpoint
   curl https://your-domain/api/v1/health

   # Run health check script
   ./scripts/maintenance/health-check.sh
   ```

8. **Update DNS** (if IP changed)
9. **Monitor logs**:
   ```bash
   ./scripts/maintenance/logs.sh --errors
   ```

### 5.2 Database Corruption Recovery

**RTO**: 2 hours

1. **Stop write operations**:
   ```bash
   docker stop forlock-api
   ```

2. **Attempt automatic repair**:
   ```bash
   docker exec forlock-postgres reindexdb -U postgres -d forlock
   docker exec forlock-postgres vacuumdb -U postgres -d forlock --full --analyze
   ```

3. **If repair fails, restore from backup**:
   ```bash
   ./scripts/maintenance/restore.sh --latest
   ```

### 5.3 Security Incident Recovery

**RTO**: 4-24 hours (varies by severity)

#### Immediate Actions (within 15 minutes)

1. **Isolate affected systems**:
   ```bash
   ufw default deny incoming
   ufw allow from <ADMIN_IP> to any port 22
   docker compose down
   ```

2. **Preserve evidence**:
   ```bash
   mkdir -p /forensic-evidence
   ./scripts/maintenance/logs.sh --export
   cp -r /var/log/forlock /forensic-evidence/
   ```

3. **Notify stakeholders** per incident response plan

4. **Rotate all credentials**:
   ```bash
   # Generate new secrets
   openssl rand -base64 64 > /tmp/new_jwt_secret
   openssl rand -base64 32 > /tmp/new_postgres_password
   ```

5. **Restore from clean backup** (taken BEFORE compromise)

---

## 6. Roles & Responsibilities

### Disaster Recovery Team

| Role | Responsibilities |
|------|-----------------|
| **DR Coordinator** | Overall DR execution, decision making |
| **Infrastructure Lead** | Server recovery, network restoration |
| **Database Administrator** | Database backup/restore, data integrity |
| **Application Lead** | Application deployment, verification |
| **Security Lead** | Security incident response, forensics |
| **Communications Lead** | Stakeholder notifications, status updates |

### On-Call Rotation
- **Primary**: [Configure your on-call system]
- **Secondary**: [Backup contact]
- **Escalation**: [Management contact]

---

## 7. Communication Plan

### Incident Severity Levels

| Level | Definition | Notification Time | Stakeholders |
|-------|-----------|-------------------|--------------|
| **P1 - Critical** | Complete outage, data loss | < 15 min | All teams, C-level |
| **P2 - High** | Partial outage, degraded performance | 30 min | DR team, management |
| **P3 - Medium** | Non-critical service down | 1 hour | DR team |
| **P4 - Low** | Monitoring alert, proactive maintenance | 4 hours | Infrastructure team |

### Customer Notification Template
```
Subject: Service Disruption - [Incident Summary]

Dear Forlock Users,

We are currently experiencing [brief description of issue]. Our team is
actively working to resolve this issue.

Current Status: [In Progress/Investigating/Resolved]
Estimated Resolution Time: [ETA or "under investigation"]
Affected Services: [List]

We will provide updates every [timeframe] or as significant progress is made.

For urgent support, please contact: [support email]

Thank you for your patience.

The Forlock Team
```

---

## 8. Testing & Maintenance

### DR Testing Schedule

| Test Type | Frequency | Scope | Success Criteria |
|-----------|-----------|-------|------------------|
| **Backup Verification** | Weekly | Automated restore to test env | Restore completes, data integrity verified |
| **Tabletop Exercise** | Quarterly | DR team walkthrough scenarios | All roles understand procedures |
| **Partial Failover Test** | Semi-annually | Single service recovery | RTO met, service functional |
| **Full DR Drill** | Annually | Complete production recovery | All services restored within RTO/RPO |

### Plan Maintenance

**Review Triggers**:
- Infrastructure changes (new services, providers)
- After each disaster recovery event
- After DR testing (lessons learned)
- Quarterly scheduled review
- Technology updates

---

## 9. Appendix

### A. Service Dependencies

```
API
├── PostgreSQL (critical)
├── Redis (high)
├── RabbitMQ (medium)
└── Vault (medium - optional)

Frontend
└── API (critical)

Nginx
├── Frontend (high)
└── API (critical)
```

### B. Recovery Time Estimates

| Component | Provisioning | Configuration | Data Restore | Verification | Total |
|-----------|--------------|---------------|--------------|--------------|-------|
| Infrastructure | 30 min | 30 min | - | 15 min | 1h 15m |
| PostgreSQL | - | 15 min | 45 min | 30 min | 1h 30m |
| Redis | - | 5 min | 10 min | 5 min | 20 min |
| API | - | 15 min | - | 15 min | 30 min |
| Frontend | - | 10 min | - | 10 min | 20 min |
| **Total** | | | | | **~4 hours** |

### C. Useful Commands Reference

**Docker Management**:
```bash
docker ps -a                    # View all containers
docker logs -f <container>      # View logs
docker exec -it <container> sh  # Execute command
docker stats                    # View resource usage
```

**PostgreSQL Maintenance**:
```bash
pg_dump -U postgres -F c -f backup.dump forlock   # Backup
pg_restore -U postgres -d forlock -c backup.dump  # Restore
vacuumdb -U postgres -d forlock --analyze         # Maintenance
```

**Using Maintenance Scripts**:
```bash
./scripts/maintenance/backup.sh           # Backup all data
./scripts/maintenance/restore.sh --list   # List backups
./scripts/maintenance/restore.sh --latest # Restore latest
./scripts/maintenance/health-check.sh     # Health check
./scripts/maintenance/logs.sh --errors    # View errors
```

---

## Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| DR Coordinator | | | |
| Infrastructure Lead | | | |
| Security Lead | | | |

---

**Next Review Date**: [3 months from approval]
**Document Classification**: CONFIDENTIAL
