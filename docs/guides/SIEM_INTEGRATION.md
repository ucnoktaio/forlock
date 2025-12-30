# Graylog Production Deployment Guide

**Document Version**: 1.0
**Last Updated**: 2025-12-21
**Purpose**: Production-ready SIEM deployment for Forlock
**Compliance**: ISO 27001:2022 A.8.16 (Monitoring activities), NIST SP 800-92 (Log Management)

---

## Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Architecture](#architecture)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Integration with Forlock](#integration-with-forlock)
7. [Security Hardening](#security-hardening)
8. [Monitoring & Maintenance](#monitoring--maintenance)
9. [Troubleshooting](#troubleshooting)
10. [Compliance](#compliance)

---

## 1. Overview

### Purpose
Graylog serves as Forlock's Security Information and Event Management (SIEM) system for:
- Centralized log aggregation
- Real-time security event detection
- Audit log analysis
- Compliance reporting (ISO 27001, NIST, SOC 2)
- Incident forensics

### Components
- **Graylog Server**: Log processing & web interface
- **OpenSearch**: Log storage & full-text search engine
- **MongoDB**: Graylog metadata storage
- **Nginx**: Reverse proxy for HTTPS

### Log Sources
- Forlock API (application logs)
- HTTP request logs (audit trail)
- PostgreSQL logs (database activity)
- Nginx access/error logs
- System logs (via Syslog)

---

## 2. System Requirements

### Minimum Requirements (Development)
| Component | CPU | RAM | Storage |
|-----------|-----|-----|---------|
| Graylog Server | 1 core | 2 GB | 10 GB |
| OpenSearch | 1 core | 2 GB | 20 GB |
| MongoDB | 0.5 core | 512 MB | 5 GB |
| **Total** | **2.5 cores** | **4.5 GB** | **35 GB** |

### Production Requirements
| Component | CPU | RAM | Storage | Notes |
|-----------|-----|-----|---------|-------|
| Graylog Server | 2-4 cores | 4-8 GB | 20 GB | Scales with log volume |
| OpenSearch | 4-8 cores | 8-16 GB | 100-500 GB | SSD recommended |
| MongoDB | 1-2 cores | 2-4 GB | 20 GB | SSD recommended |
| **Total** | **7-14 cores** | **14-28 GB** | **140-540 GB** | |

### Storage Recommendations
- **Log Retention**: 90 days (compliance requirement)
- **Daily Log Volume**: ~10-50 GB (depends on traffic)
- **Total Storage**: 1-5 TB recommended (with compression)
- **IOPS**: 1000+ for OpenSearch (SSD required)

### Network Requirements
- **Inbound**:
  - Syslog (UDP/TCP): 514, 1514
  - GELF (UDP/TCP): 12201
  - Beats (TCP): 5044
  - Web UI (HTTP/HTTPS): 9000 (proxied via Nginx)
- **Outbound**:
  - SMTP (Email alerts): 25, 587
  - Webhook notifications: 443

---

## 3. Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     Nginx Reverse Proxy                  │
│                  HTTPS :443 → HTTP :9000                 │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐ ┌────────▼───────┐ ┌────────▼───────┐
│  Forlock API   │ │  Forlock Nginx │ │  PostgreSQL    │
│  (Serilog →)   │ │  (access logs) │ │  (query logs)  │
│  GELF :12201   │ │  Syslog :1514  │ │  Syslog :1514  │
└────────┬───────┘ └────────┬───────┘ └────────┬───────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
                   ┌────────▼───────┐
                   │ Graylog Server │
                   │  Port: 9000    │
                   │  GELF: 12201   │
                   │  Syslog: 1514  │
                   └────────┬───────┘
         ┌──────────────────┼──────────────────┐
         │                  │                  │
┌────────▼────────┐ ┌───────▼────────┐ ┌──────▼───────┐
│   OpenSearch    │ │    MongoDB     │ │  Alerting    │
│  (Log Storage)  │ │  (Metadata)    │ │  (SMTP/API)  │
│   Port: 9200    │ │  Port: 27017   │ │              │
└─────────────────┘ └────────────────┘ └──────────────┘
```

### Data Flow
1. **Forlock API** → Serilog → GELF → Graylog (UDP :12201)
2. **Nginx** → Access logs → Syslog → Graylog (TCP :1514)
3. **PostgreSQL** → Query logs → Syslog → Graylog (TCP :1514)
4. **Graylog** → Parse & Process → OpenSearch
5. **Users** → Web UI (HTTPS :443) → Graylog Dashboard

---

## 4. Installation

### Option A: Docker Compose (Recommended)

Create `docker-compose.graylog.yml`:

```yaml
version: '3.8'

services:
  # MongoDB - Graylog Metadata Store
  graylog-mongodb:
    image: mongo:7.0
    container_name: graylog-mongodb-prod
    restart: always
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD}
      MONGO_INITDB_DATABASE: graylog
    volumes:
      - graylog_mongodb_data:/data/db
      - graylog_mongodb_config:/data/configdb
    networks:
      - graylog-network
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 30s
      timeout: 10s
      retries: 5

  # OpenSearch - Log Storage & Search
  opensearch:
    image: opensearchproject/opensearch:2.11.1
    container_name: graylog-opensearch-prod
    restart: always
    environment:
      - discovery.type=single-node
      - cluster.name=graylog-prod
      - node.name=opensearch-node1
      - bootstrap.memory_lock=false
      - "OPENSEARCH_JAVA_OPTS=-Xms8g -Xmx8g"  # 50% of container memory
      - DISABLE_INSTALL_DEMO_CONFIG=true
      - DISABLE_SECURITY_PLUGIN=true  # Graylog handles auth
      - action.auto_create_index=false
      - plugins.security.disabled=true
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - opensearch_data:/usr/share/opensearch/data
    networks:
      - graylog-network
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 16G
        reservations:
          cpus: '4'
          memory: 8G
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Graylog Server
  graylog:
    image: graylog/graylog:5.2
    container_name: graylog-server-prod
    restart: always
    depends_on:
      graylog-mongodb:
        condition: service_healthy
      opensearch:
        condition: service_healthy
    environment:
      # Admin Credentials
      GRAYLOG_PASSWORD_SECRET: ${GRAYLOG_PASSWORD_SECRET}  # Min 64 chars
      GRAYLOG_ROOT_PASSWORD_SHA2: ${GRAYLOG_ROOT_PASSWORD_SHA2}  # SHA-256 hash
      GRAYLOG_ROOT_USERNAME: ${GRAYLOG_ROOT_USERNAME:-admin}

      # HTTP Configuration
      GRAYLOG_HTTP_EXTERNAL_URI: ${GRAYLOG_EXTERNAL_URI:-https://logs.forlock.io/}
      GRAYLOG_HTTP_PUBLISH_URI: ${GRAYLOG_EXTERNAL_URI:-https://logs.forlock.io/}
      GRAYLOG_HTTP_BIND_ADDRESS: 0.0.0.0:9000

      # OpenSearch Connection
      GRAYLOG_ELASTICSEARCH_HOSTS: http://opensearch:9200
      GRAYLOG_ELASTICSEARCH_VERSION: 7  # OpenSearch compatibility

      # MongoDB Connection
      GRAYLOG_MONGODB_URI: mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@graylog-mongodb:27017/graylog

      # Timezone & Locale
      GRAYLOG_ROOT_TIMEZONE: UTC
      GRAYLOG_ROOT_EMAIL: ${GRAYLOG_ROOT_EMAIL}

      # Email Configuration (Optional)
      GRAYLOG_TRANSPORT_EMAIL_ENABLED: ${SMTP_ENABLED:-false}
      GRAYLOG_TRANSPORT_EMAIL_HOSTNAME: ${SMTP_HOST}
      GRAYLOG_TRANSPORT_EMAIL_PORT: ${SMTP_PORT:-587}
      GRAYLOG_TRANSPORT_EMAIL_USE_AUTH: ${SMTP_USE_AUTH:-true}
      GRAYLOG_TRANSPORT_EMAIL_USE_TLS: ${SMTP_USE_TLS:-true}
      GRAYLOG_TRANSPORT_EMAIL_USE_SSL: ${SMTP_USE_SSL:-false}
      GRAYLOG_TRANSPORT_EMAIL_AUTH_USERNAME: ${SMTP_USERNAME}
      GRAYLOG_TRANSPORT_EMAIL_AUTH_PASSWORD: ${SMTP_PASSWORD}
      GRAYLOG_TRANSPORT_EMAIL_FROM_EMAIL: ${SMTP_FROM_EMAIL:-noreply@forlock.io}

      # Performance Tuning
      GRAYLOG_PROCESSBUFFER_PROCESSORS: 5
      GRAYLOG_OUTPUTBUFFER_PROCESSORS: 3
      GRAYLOG_PROCESSOR_WAIT_STRATEGY: blocking
      GRAYLOG_RING_SIZE: 65536
      GRAYLOG_INPUTBUFFER_RING_SIZE: 65536
      GRAYLOG_ASYNC_EVENTBUS_PROCESSORS: 2

      # Log Retention (90 days compliance)
      GRAYLOG_ALLOW_HIGHLIGHTING: true
      GRAYLOG_ALLOW_LEADING_WILDCARD_SEARCHES: false

    ports:
      - "9000:9000"    # Web UI
      - "12201:12201/udp"  # GELF UDP
      - "12201:12201/tcp"  # GELF TCP
      - "1514:1514/tcp"    # Syslog TCP
      - "1514:1514/udp"    # Syslog UDP
      - "5044:5044/tcp"    # Beats (optional)

    volumes:
      - graylog_data:/usr/share/graylog/data
      - graylog_journal:/usr/share/graylog/data/journal
      - ./graylog/config:/usr/share/graylog/data/config

    networks:
      - graylog-network
      - forlock-network  # Connect to Forlock services

    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G

    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/api/system/lbstatus || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

volumes:
  graylog_mongodb_data:
    driver: local
  graylog_mongodb_config:
    driver: local
  opensearch_data:
    driver: local
  graylog_data:
    driver: local
  graylog_journal:
    driver: local

networks:
  graylog-network:
    driver: bridge
  forlock-network:
    external: true  # Connect to existing Forlock network
```

### Deploy Graylog

```bash
# 1. Create .env.graylog file
cat > .env.graylog <<EOF
# MongoDB Credentials
MONGO_ROOT_USER=graylog_admin
MONGO_ROOT_PASSWORD=$(openssl rand -base64 32)

# Graylog Admin Credentials
GRAYLOG_ROOT_USERNAME=admin
GRAYLOG_ROOT_PASSWORD=YourSecurePassword  # Change this!
GRAYLOG_PASSWORD_SECRET=$(openssl rand -base64 64)
GRAYLOG_ROOT_PASSWORD_SHA2=$(echo -n "YourSecurePassword" | sha256sum | cut -d" " -f1)
GRAYLOG_ROOT_EMAIL=admin@forlock.io

# External URL
GRAYLOG_EXTERNAL_URI=https://logs.forlock.io/

# SMTP Configuration (Optional)
SMTP_ENABLED=false
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USE_AUTH=true
SMTP_USE_TLS=true
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=noreply@forlock.io
EOF

# 2. Source environment variables
set -a && source .env.graylog && set +a

# 3. Deploy Graylog stack
docker compose -f docker-compose.graylog.yml up -d

# 4. Check deployment status
docker compose -f docker-compose.graylog.yml ps
docker logs -f graylog-server-prod
```

### Initial Setup

1. **Access Graylog Web UI**:
   - URL: `https://logs.forlock.io` (or `http://localhost:9000`)
   - Username: `admin`
   - Password: (from `.env.graylog`)

2. **Complete Setup Wizard**:
   - Set timezone: UTC
   - Configure email settings (optional)
   - Create initial inputs

---

## 5. Configuration

### 5.1 Create Input for Forlock API (GELF)

1. Navigate to: **System → Inputs**
2. Select input type: **GELF UDP**
3. Click: **Launch new input**
4. Configure:
   - **Title**: `Forlock API (GELF)`
   - **Bind address**: `0.0.0.0`
   - **Port**: `12201`
   - **Receive buffer size**: `262144` (256 KB)
5. Click: **Save**

### 5.2 Create Input for Syslog

1. Select input type: **Syslog TCP**
2. Configure:
   - **Title**: `System Logs (Syslog)`
   - **Bind address**: `0.0.0.0`
   - **Port**: `1514`
   - **Store full message**: `Yes`
3. Click: **Save**

### 5.3 Create Streams

**Stream 1: Forlock Security Events**
```
Navigate to: Streams → Create Stream
Title: Forlock Security Events
Description: Security-related audit logs
Rules:
  - Field: source
    Type: match exactly
    Value: forlock-api
  - Field: EventCategory
    Type: match exactly
    Value: Security
```

**Stream 2: Forlock Audit Logs**
```
Title: Forlock Audit Logs
Rules:
  - Field: source
    Type: match exactly
    Value: forlock-api
  - Field: logger_name
    Type: match regular expression
    Value: Ucnokta.Forlock.Api.Middleware.AuditLoggingMiddleware
```

**Stream 3: High Severity Errors**
```
Title: High Severity Errors
Rules:
  - Field: level
    Type: match exactly
    Value: error
  OR
  - Field: EventSeverity
    Type: match exactly
    Value: Critical
```

### 5.4 Index Retention

1. Navigate to: **System → Indices**
2. Click on default index set
3. Configure rotation & retention:
   - **Rotation Strategy**: Index Time (daily)
   - **Max number of indices**: `90` (90 days)
   - **Retention Strategy**: Delete
   - **Index Shards**: `4`
   - **Index Replicas**: `0` (single node)

### 5.5 Alerting Configuration

**Alert 1: Failed Login Attempts**
```
Navigate to: Alerts → Event Definitions → Create Event Definition

Title: Multiple Failed Login Attempts
Priority: High
Description: Detects brute-force login attempts

Condition:
  Type: Filter & Aggregation
  Search Query: EventType:"user.login.failed"
  Streams: Forlock Security Events
  Search within: 5 minutes
  Execute every: 1 minute
  Threshold: Count() > 5
  Group by: source_ip

Notifications:
  - Email to: security@forlock.io
  - Subject: [ALERT] Multiple failed logins from {source_ip}
```

**Alert 2: Critical Security Events**
```
Title: Critical Security Event
Priority: Critical

Condition:
  Search Query: EventSeverity:"Critical"
  Threshold: Count() > 0
  Execute every: 1 minute

Notifications:
  - Email to: security@forlock.io
  - Slack webhook (optional)
```

---

## 6. Integration with Forlock

### 6.1 Configure Forlock API Logging

Already configured in `appsettings.json`:

```json
{
  "Serilog": {
    "WriteTo": [
      {
        "Name": "Graylog",
        "Args": {
          "hostnameOrAddress": "graylog-server-prod",
          "port": "12201",
          "transportType": "Udp",
          "facility": "forlock-api"
        }
      }
    ]
  }
}
```

### 6.2 Verify Integration

```bash
# Test GELF connection
echo '{"version":"1.1","host":"test","short_message":"Test from CLI"}' | \
  nc -u graylog-server-prod 12201

# Check Graylog logs
docker logs graylog-server-prod | grep "GELF"

# View in Graylog UI
# Navigate to: Search → All messages
# Filter: source:test
```

---

## 7. Security Hardening

### 7.1 Nginx Reverse Proxy for HTTPS

Add to `/nginx/nginx.conf`:

```nginx
upstream graylog {
    server graylog-server-prod:9000;
}

server {
    listen 443 ssl http2;
    server_name logs.forlock.io;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/logs.forlock.io.crt;
    ssl_certificate_key /etc/nginx/ssl/logs.forlock.io.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Graylog Proxy
    location / {
        proxy_pass http://graylog;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Graylog-Server-URL https://logs.forlock.io/;
    }

    # WebSocket support (for real-time updates)
    location /api {
        proxy_pass http://graylog;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 7.2 Firewall Rules

```bash
# Allow only from trusted IPs
ufw allow from YOUR_APP_SERVER_IP to any port 12201 proto udp comment 'Graylog GELF'
ufw allow from YOUR_APP_SERVER_IP to any port 1514 proto tcp comment 'Graylog Syslog'

# Block direct access to Graylog web UI (use Nginx proxy only)
ufw deny 9000/tcp comment 'Graylog web UI - use HTTPS proxy'
```

### 7.3 User Access Control

1. **Create admin user**:
   - Navigate to: System → Users
   - Create user with `Admin` role

2. **Create read-only analyst role**:
   - Navigate to: System → Roles
   - Create role: `Security Analyst`
   - Permissions: `streams:read`, `dashboards:read`

3. **Disable default admin** (after creating backup admin):
   - Navigate to: System → Users → admin
   - Click: Edit → Disable

---

## 8. Monitoring & Maintenance

### 8.1 Health Checks

```bash
# Check Graylog health
curl http://localhost:9000/api/system/lbstatus

# Check OpenSearch cluster health
curl http://localhost:9200/_cluster/health

# Check MongoDB
docker exec graylog-mongodb-prod mongosh --eval "db.adminCommand('ping')"
```

### 8.2 Backup Strategy

**MongoDB Backup** (daily):
```bash
#!/bin/bash
docker exec graylog-mongodb-prod mongodump \
  --out=/tmp/backup-$(date +%Y%m%d) \
  --username=${MONGO_ROOT_USER} \
  --password=${MONGO_ROOT_PASSWORD}

docker cp graylog-mongodb-prod:/tmp/backup-$(date +%Y%m%d) /backups/graylog/
```

**OpenSearch Snapshot** (weekly):
```bash
# Register snapshot repository
curl -X PUT "http://localhost:9200/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/mnt/backups/opensearch"
  }
}'

# Create snapshot
curl -X PUT "http://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)"
```

### 8.3 Log Rotation

Graylog automatically rotates indices based on configuration (Section 5.4).

**Manual cleanup**:
```bash
# Delete indices older than 90 days
curl -X DELETE "http://localhost:9200/graylog_*_2024*"
```

### 8.4 Performance Tuning

**OpenSearch JVM Heap**:
- Set to 50% of container memory
- Max: 32 GB (Java compressed pointers limit)

**Graylog Processing**:
```
GRAYLOG_PROCESSBUFFER_PROCESSORS=5  # CPU cores - 1
GRAYLOG_OUTPUTBUFFER_PROCESSORS=3
GRAYLOG_RING_SIZE=65536  # Increase for high volume
```

---

## 9. Troubleshooting

### 9.1 Common Issues

**Issue**: Graylog can't connect to OpenSearch
```bash
# Check OpenSearch is running
docker logs graylog-opensearch-prod

# Test connection
curl http://localhost:9200/_cluster/health

# Check Graylog config
docker exec graylog-server-prod cat /usr/share/graylog/data/config/graylog.conf | grep elasticsearch
```

**Issue**: No logs appearing
```bash
# Check inputs are running
curl -u admin:password http://localhost:9000/api/system/inputs

# Test GELF input
echo '{"version":"1.1","host":"test","short_message":"Test"}' | nc -u localhost 12201

# Check Graylog processing
docker exec graylog-server-prod /usr/share/graylog/bin/graylogctl status
```

**Issue**: High memory usage
```bash
# Reduce OpenSearch heap
# Edit docker-compose.graylog.yml:
OPENSEARCH_JAVA_OPTS=-Xms4g -Xmx4g

# Reduce retention period
# Graylog UI: System → Indices → Edit → Max indices: 30
```

---

## 10. Compliance

### ISO 27001:2022 Requirements

| Control | Requirement | Implementation |
|---------|-------------|----------------|
| **A.8.16** | Monitoring activities | Graylog SIEM, real-time alerts |
| **A.12.4.1** | Event logging | All security events logged |
| **A.12.4.2** | Log protection | Immutable indices, access control |
| **A.12.4.3** | Administrator logs | Dedicated audit stream |
| **A.12.4.4** | Clock synchronization | UTC timezone enforced |

### NIST SP 800-92 (Log Management)

- ✅ Centralized log management
- ✅ Log retention (90 days minimum)
- ✅ Log integrity protection
- ✅ Access control (RBAC)
- ✅ Regular log review (dashboards)
- ✅ Incident response integration

### Data Retention

**Compliance Requirements**:
- **ISO 27001**: Logs retained per legal/regulatory requirements
- **GDPR**: Personal data in logs (IP, usernames) = 90 days
- **KVKK**: Audit logs = 2 years minimum
- **SOC 2**: Security logs = 1 year minimum

**Forlock Configuration**:
- **Default**: 90 days (daily rotation)
- **Audit logs**: Forward to long-term storage (PostgreSQL)
- **Critical events**: Separate retention (365 days)

---

## Next Steps

1. ✅ Deploy Graylog stack
2. ⏳ Configure inputs (GELF, Syslog)
3. ⏳ Create streams & dashboards
4. ⏳ Setup alerting rules
5. ⏳ Integrate with Forlock API
6. ⏳ Configure backup automation
7. ⏳ Test disaster recovery
8. ⏳ Train security team

---

## Support

**Resources**:
- Graylog Documentation: https://docs.graylog.org/
- OpenSearch Documentation: https://opensearch.org/docs/
- Community Forum: https://community.graylog.org/

**Forlock Team**:
- Security: security@forlock.io
- Infrastructure: infrastructure@forlock.io
- On-call: (see DISASTER_RECOVERY_PLAN.md)
