# ModSecurity WAF Deployment Guide

**Document Version**: 1.0
**Last Updated**: 2025-12-21
**Purpose**: Deploy ModSecurity Web Application Firewall with OWASP Core Rule Set
**Compliance**: NIST PR.PT (Protective Technology), OWASP Top 10 Protection

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [OWASP CRS Rules](#owasp-crs-rules)
6. [Testing](#testing)
7. [Monitoring](#monitoring)
8. [Troubleshooting](#troubleshooting)

---

## 1. Overview

### What is ModSecurity?
ModSecurity is an open-source Web Application Firewall (WAF) that provides protection against:
- **SQL Injection** (CWE-89)
- **Cross-Site Scripting (XSS)** (CWE-79)
- **Remote File Inclusion** (CWE-98)
- **Command Injection** (CWE-78)
- **Path Traversal** (CWE-22)
- **OWASP Top 10** vulnerabilities

### OWASP Core Rule Set (CRS)
- Community-maintained security rules
- 200+ rules covering common attacks
- Paranoia levels (1-4) for sensitivity
- Regular updates for new threats

### Benefits for Forlock
- Defense in depth (even if app vulnerable)
- Zero-day protection
- Compliance (PCI DSS 6.6, NIST PR.PT)
- Attack visibility and logging

---

## 2. Architecture

### Before WAF
```
Internet → Nginx → Forlock API
```

### After WAF
```
Internet → Nginx (ModSecurity WAF) → Forlock API
                 ↓
             WAF Logs → Graylog
```

### ModSecurity Deployment Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Detection Only** | Logs attacks, doesn't block | Testing, tuning |
| **Blocking** | Logs and blocks attacks | Production |

**Recommended**: Start in Detection mode, tune for 1-2 weeks, then enable Blocking.

---

## 3. Installation

### Option A: Docker-based ModSecurity (Recommended)

Create custom Nginx image with ModSecurity:

**File**: `nginx/Dockerfile.modsecurity`

```dockerfile
FROM nginx:1.25-alpine

# Install ModSecurity dependencies
RUN apk add --no-cache \
    libmodsecurity3 \
    libmodsecurity3-dev \
    nginx-mod-http-modsecurity

# Copy ModSecurity configuration
COPY modsec/ /etc/nginx/modsec/

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
```

**Build and deploy**:
```bash
# Build custom image
cd nginx
docker build -t forlock-nginx-waf:latest -f Dockerfile.modsecurity .

# Update docker-compose.yml
# Replace nginx image with: forlock-nginx-waf:latest

# Restart nginx
docker compose restart nginx
```

---

### Option B: Native Installation (Ubuntu)

```bash
# Install ModSecurity library
apt-get update
apt-get install -y libmodsecurity3 libmodsecurity3-dev

# Install Nginx ModSecurity module
apt-get install -y libnginx-mod-http-modsecurity

# Verify installation
nginx -V 2>&1 | grep modsecurity

# Expected output: --add-module=ngx_http_modsecurity_module
```

---

## 4. Configuration

### 4.1 ModSecurity Main Configuration

**File**: `nginx/modsec/modsecurity.conf`

```nginx
# ModSecurity Core Configuration
# Based on: https://github.com/SpiderLabs/ModSecurity/blob/master/modsecurity.conf-recommended

# Enable ModSecurity
SecRuleEngine On

# Request body handling
SecRequestBodyAccess On
SecRequestBodyLimit 13107200  # 12.5 MB
SecRequestBodyNoFilesLimit 131072  # 128 KB
SecRequestBodyLimitAction Reject

# Response body handling
SecResponseBodyAccess On
SecResponseBodyMimeType text/plain text/html text/xml application/json
SecResponseBodyLimit 524288  # 512 KB
SecResponseBodyLimitAction ProcessPartial

# File uploads
SecTmpDir /tmp/
SecUploadDir /tmp/
SecUploadKeepFiles Off
SecUploadFileMode 0600

# Debug log (disable in production)
SecDebugLog /var/log/nginx/modsec_debug.log
SecDebugLogLevel 0  # 0=Off, 9=Very verbose

# Audit logging
SecAuditEngine RelevantOnly  # Only log blocked requests
SecAuditLogRelevantStatus "^(?:5|4(?!04))"  # 4xx/5xx except 404
SecAuditLogParts ABIJDEFHZ  # All parts except C (request body)
SecAuditLogType Serial
SecAuditLog /var/log/nginx/modsec_audit.log

# Argument separator (for URL parsing)
SecArgumentSeparator &

# Cookie format
SecCookieFormat 0

# Unicode mapping
SecUnicodeMapFile /etc/nginx/modsec/unicode.mapping

# Ruleset compatibility
SecStatusEngine On

# Collection timeout (session tracking)
SecCollectionTimeout 600  # 10 minutes

# -- Rule Engine Initialization --
# Explicitly initialize rule engine
SecAction \
  "id:900000,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.paranoia_level=1"
```

**File**: `nginx/modsec/unicode.mapping`

Download from:
```bash
wget https://raw.githubusercontent.com/SpiderLabs/ModSecurity/master/unicode.mapping \
  -O nginx/modsec/unicode.mapping
```

---

### 4.2 OWASP CRS Installation

```bash
# Download OWASP CRS
cd nginx/modsec
wget https://github.com/coreruleset/coreruleset/archive/refs/tags/v4.0.0.tar.gz
tar -xzf v4.0.0.tar.gz
mv coreruleset-4.0.0 owasp-crs

# Setup CRS configuration
cd owasp-crs
cp crs-setup.conf.example crs-setup.conf

# Edit crs-setup.conf
nano crs-setup.conf
```

**Key CRS Settings** (`crs-setup.conf`):

```nginx
# Paranoia Level (1-4)
# 1 = Low (fewest false positives, recommended for production)
# 2 = Medium
# 3 = High
# 4 = Extreme (many false positives)
SecAction \
  "id:900000,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.paranoia_level=1"

# Anomaly Scoring Threshold
# Inbound: Sum of all rule scores
# Outbound: Response anomaly score
SecAction \
  "id:900110,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.inbound_anomaly_score_threshold=5,\
   setvar:tx.outbound_anomaly_score_threshold=4"

# Blocking Mode
# on = Block requests
# off = Detection only (log but don't block)
SecAction \
  "id:900120,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.blocking_paranoia_level=1"

# Allowed HTTP Methods
SecAction \
  "id:900200,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:'tx.allowed_methods=GET HEAD POST OPTIONS PUT PATCH DELETE'"

# Content Types
SecAction \
  "id:900220,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:'tx.allowed_request_content_type=|application/x-www-form-urlencoded| |multipart/form-data| |multipart/related| |text/xml| |application/xml| |application/soap+xml| |application/json| |application/cloudevents+json| |application/cloudevents-batch+json|'"

# File Extensions
SecAction \
  "id:900240,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:'tx.restricted_extensions=.asa/ .asax/ .ascx/ .axd/ .backup/ .bak/ .bat/ .cdx/ .cer/ .cfg/ .cmd/ .com/ .config/ .conf/ .cs/ .csproj/ .csr/ .dat/ .db/ .dbf/ .dll/ .dos/ .htr/ .htw/ .ida/ .idc/ .idq/ .inc/ .ini/ .key/ .licx/ .lnk/ .log/ .mdb/ .old/ .pass/ .pdb/ .pol/ .printer/ .pwd/ .rdb/ .resources/ .resx/ .sql/ .swp/ .sys/ .vb/ .vbs/ .vbproj/ .vsdisco/ .webinfo/ .xsd/ .xsx/'"
```

---

### 4.3 Main ModSecurity Include File

**File**: `nginx/modsec/main.conf`

```nginx
# Include ModSecurity recommended config
Include /etc/nginx/modsec/modsecurity.conf

# OWASP CRS v4.0
Include /etc/nginx/modsec/owasp-crs/crs-setup.conf
Include /etc/nginx/modsec/owasp-crs/rules/*.conf

# Custom rules for Forlock
Include /etc/nginx/modsec/forlock-custom-rules.conf
```

---

### 4.4 Forlock Custom Rules

**File**: `nginx/modsec/forlock-custom-rules.conf`

```nginx
# Forlock-Specific ModSecurity Rules
# Author: Forlock Security Team
# Last Updated: 2025-12-21

# Whitelist Forlock API health checks
SecRule REQUEST_URI "@streq /api/v1/health" \
    "id:1000,\
     phase:1,\
     t:none,\
     nolog,\
     allow"

# Allow Swagger/API documentation (development only)
SecRule REQUEST_URI "@beginsWith /swagger" \
    "id:1001,\
     phase:1,\
     t:none,\
     nolog,\
     allow"

# Rate limiting for login endpoint (additional layer)
SecRule REQUEST_URI "@streq /api/v1/auth/login" \
    "id:1002,\
     phase:2,\
     t:none,\
     chain,\
     deny,\
     status:429,\
     msg:'Login rate limit exceeded'"
    SecRule &IP:LOGIN_ATTEMPT "@gt 10" \
        "t:none,\
         expirevar:IP:LOGIN_ATTEMPT=60"

# Block known attack patterns in query strings
SecRule ARGS "@rx (?i:(?:union.*select|insert.*into|delete.*from|drop.*table))" \
    "id:1003,\
     phase:2,\
     t:none,\
     deny,\
     status:403,\
     msg:'SQL injection attempt detected',\
     severity:CRITICAL,\
     tag:'OWASP_CRS',\
     tag:'SQLI'"

# Block path traversal attempts
SecRule REQUEST_URI "@rx (?:\.\.\/|\.\.\\)" \
    "id:1004,\
     phase:1,\
     t:none,\
     deny,\
     status:403,\
     msg:'Path traversal attempt detected',\
     severity:WARNING,\
     tag:'PATH_TRAVERSAL'"

# Whitelist legitimate admin panel access
SecRule REMOTE_ADDR "@ipMatch your-server-ip" \
    "id:1005,\
     phase:1,\
     t:none,\
     nolog,\
     ctl:ruleRemoveById=920350"  # Allow large POST bodies for admin

# Custom detection: Vault export rate limiting
SecRule REQUEST_URI "@streq /api/v1/vaults/export" \
    "id:1006,\
     phase:1,\
     t:none,\
     chain,\
     deny,\
     status:429,\
     msg:'Vault export rate limit - potential data exfiltration'"
    SecRule &IP:VAULT_EXPORT "@gt 5" \
        "t:none,\
         expirevar:IP:VAULT_EXPORT=3600"  # 5 exports per hour

# Honeypot: Detect scanning for common CMS vulnerabilities
SecRule REQUEST_URI "@rx (?i:(?:wp-admin|wp-login|phpmyadmin|adminer))" \
    "id:1007,\
     phase:1,\
     t:none,\
     deny,\
     status:404,\
     msg:'Scanning for common CMS - potential attack',\
     severity:WARNING,\
     tag:'SCANNER_DETECTION',\
     setvar:ip.scanner_score=+10"

# Block if scanner score exceeds threshold
SecRule IP:SCANNER_SCORE "@gt 30" \
    "id:1008,\
     phase:1,\
     t:none,\
     deny,\
     status:403,\
     msg:'High scanner score - IP blocked for 1 hour',\
     severity:CRITICAL,\
     expirevar:IP:SCANNER_SCORE=3600"
```

---

### 4.5 Nginx Configuration Integration

**File**: `nginx/nginx.conf` (add ModSecurity directives)

```nginx
# Load ModSecurity module
load_module modules/ngx_http_modsecurity_module.so;

http {
    # ... existing config ...

    # ModSecurity enabled globally
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;

    # Optional: Per-location ModSecurity
    server {
        listen 80;
        server_name forlock.io;

        # Disable ModSecurity for health checks
        location /health {
            modsecurity off;
            proxy_pass http://api:8080;
        }

        # Enable ModSecurity for API
        location /api {
            modsecurity on;
            modsecurity_rules_file /etc/nginx/modsec/main.conf;

            proxy_pass http://api:8080;
            # ... proxy headers ...
        }

        # Strict ModSecurity for admin panel
        location /admin {
            modsecurity on;
            modsecurity_rules '
                SecRuleEngine On
                SecAction "id:9001,phase:1,pass,setvar:tx.blocking_paranoia_level=2"
            ';

            proxy_pass http://frontend:80;
        }
    }
}
```

---

## 5. OWASP CRS Rules

### Rule Categories (CRS 4.0)

| ID Range | Category | Examples |
|----------|----------|----------|
| **920xxx** | Protocol Enforcement | HTTP method, headers |
| **921xxx** | Protocol Attack | Request smuggling, HPP |
| **930xxx** | Application Attack LFI | Path traversal, file inclusion |
| **931xxx** | Application Attack RFI | Remote file inclusion |
| **932xxx** | Application Attack RCE | Command injection |
| **933xxx** | Application Attack PHP | PHP injection |
| **941xxx** | Application Attack XSS | Cross-site scripting |
| **942xxx** | Application Attack SQLI | SQL injection |
| **943xxx** | Application Attack Session | Session fixation |
| **944xxx** | Application Attack Java | Java attacks |

### Anomaly Scoring

Each rule assigns a score (not binary block):
- **CRITICAL**: 5 points
- **ERROR**: 4 points
- **WARNING**: 3 points
- **NOTICE**: 2 points

**Threshold** (default: 5 points):
- Score >= 5 → Request blocked
- Score < 5 → Request allowed

**Example**:
- SQL keyword (score: 3) + Union keyword (score: 3) = 6 → **BLOCKED**
- Single benign SQL keyword (score: 3) = 3 → **ALLOWED**

---

## 6. Testing

### 6.1 Basic Functionality Test

```bash
# Test 1: Normal request (should pass)
curl -X POST https://forlock.io/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"test"}'

# Expected: 200 OK or 401 Unauthorized (not blocked by WAF)
```

### 6.2 Attack Simulation

```bash
# Test 2: SQL Injection (should block)
curl "https://forlock.io/api/v1/users?id=1' OR '1'='1"

# Expected: 403 Forbidden
# WAF Log: "SQL injection attempt detected"

# Test 3: XSS (should block)
curl -X POST https://forlock.io/api/v1/vaults \
  -H "Content-Type: application/json" \
  -d '{"name":"<script>alert(1)</script>"}'

# Expected: 403 Forbidden
# WAF Log: "XSS attack detected"

# Test 4: Path Traversal (should block)
curl "https://forlock.io/api/../../etc/passwd"

# Expected: 403 Forbidden

# Test 5: Command Injection (should block)
curl -X POST https://forlock.io/api/v1/vaults \
  -d '{"name":"test; rm -rf /"}'

# Expected: 403 Forbidden
```

### 6.3 False Positive Testing

```bash
# Test 6: Legitimate complex password (might trigger)
curl -X POST https://forlock.io/api/v1/auth/register \
  -d '{"password":"P@ssw0rd!<>[]{}|"}'

# If blocked: Add exclusion rule
```

---

## 7. Monitoring

### 7.1 ModSecurity Logs

**Audit Log**: `/var/log/nginx/modsec_audit.log`
```
Format: [timestamp] [client] [severity] [msg] [uri] [unique_id]
Example:
[21/Dec/2025:14:30:00 +0000] 192.168.1.100 CRITICAL SQL injection attempt detected /api/v1/users 1234567890
```

**Debug Log**: `/var/log/nginx/modsec_debug.log` (disable in production)

---

### 7.2 Graylog Integration

Forward ModSecurity logs to Graylog:

**File**: `nginx/modsec/modsecurity.conf` (add)

```nginx
# JSON audit logging (easier to parse)
SecAuditLogFormat JSON
SecAuditLog |/usr/bin/logger -t modsecurity -p local6.info
```

**Configure syslog forwarding**:
```bash
# Edit /etc/rsyslog.conf
local6.* @@graylog-server-prod:1514

# Restart rsyslog
systemctl restart rsyslog
```

**Graylog Stream**:
- Create input: Syslog TCP (port 1514)
- Create stream: "ModSecurity WAF"
- Extractors: Parse JSON audit log

---

### 7.3 Metrics Dashboard

**Grafana/Graylog Dashboard Widgets**:
1. **Blocked Requests (24h)**
   - Query: `tag:OWASP_CRS AND action:blocked`
   - Visualization: Time series graph

2. **Attack Types Distribution**
   - Query: `source:modsecurity`
   - Group by: `msg` field
   - Visualization: Pie chart

3. **Top Attacking IPs**
   - Query: `action:blocked`
   - Group by: `client_ip`
   - Visualization: Table

4. **False Positive Rate**
   - Query: `severity:WARNING AND action:blocked`
   - Metric: Count / Total Requests

---

## 8. Troubleshooting

### Issue 1: All Requests Blocked

**Symptom**: Even legitimate requests return 403

**Solution**:
```nginx
# Check paranoia level (in crs-setup.conf)
# Reduce from 2 → 1
setvar:tx.paranoia_level=1

# Or disable blocking temporarily
SecRuleEngine DetectionOnly

# Restart Nginx
docker restart forlock-nginx-prod
```

---

### Issue 2: False Positives

**Symptom**: Legitimate requests blocked (e.g., complex passwords)

**Solution**:
```nginx
# Add exclusion rule in forlock-custom-rules.conf

# Example: Allow special chars in password field
SecRuleUpdateTargetById 942100 "!ARGS:password"

# Or whitelist specific user-agent
SecRule REQUEST_HEADERS:User-Agent "@streq PostmanRuntime" \
    "id:9000,\
     phase:1,\
     nolog,\
     allow"
```

---

### Issue 3: Performance Degradation

**Symptom**: Nginx slow after enabling ModSecurity

**Solution**:
```nginx
# Reduce logging verbosity
SecAuditEngine RelevantOnly  # Only log blocks
SecAuditLogParts ABIJZ  # Minimal parts

# Disable response body inspection (if not needed)
SecResponseBodyAccess Off

# Increase worker processes (nginx.conf)
worker_processes auto;
```

---

### Issue 4: Rules Not Loading

**Symptom**: WAF not blocking known attacks

**Check**:
```bash
# Test ModSecurity config
nginx -t -c /etc/nginx/nginx.conf

# Check if rules loaded
grep "Loading" /var/log/nginx/error.log

# Expected: "Loading OWASP CRS rules..."
```

---

## 9. Maintenance

### Monthly Tasks
- [ ] Review ModSecurity audit logs
- [ ] Update OWASP CRS to latest version
- [ ] Tune false positive rules
- [ ] Check blocked IPs (clean up old blocks)

### Quarterly Tasks
- [ ] Security review (effectiveness assessment)
- [ ] Paranoia level evaluation (can we increase?)
- [ ] Custom rules review (still relevant?)
- [ ] Performance benchmarking

### Annual Tasks
- [ ] Full WAF penetration test
- [ ] Rule set comparison (CRS alternatives?)
- [ ] Compliance audit (PCI DSS 6.6)

---

## 10. Compliance Mapping

| Standard | Requirement | ModSecurity Implementation |
|----------|------------|---------------------------|
| **OWASP Top 10** | A03:2021 Injection | Rules 942xxx (SQLI), 932xxx (RCE) |
| **OWASP Top 10** | A07:2021 XSS | Rules 941xxx |
| **PCI DSS 6.6** | WAF or code review | ModSecurity WAF ✅ |
| **NIST PR.PT** | Protective Technology | Attack prevention layer |
| **ISO 27001 A.14.1.2** | Security in development | Additional security control |

---

## Appendix: Quick Reference

### Enable/Disable WAF
```bash
# Disable (emergency)
docker exec forlock-nginx-prod sed -i 's/SecRuleEngine On/SecRuleEngine Off/' /etc/nginx/modsec/modsecurity.conf
docker restart forlock-nginx-prod

# Enable
docker exec forlock-nginx-prod sed -i 's/SecRuleEngine Off/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf
docker restart forlock-nginx-prod
```

### View Blocked Requests (Real-time)
```bash
tail -f /var/log/nginx/modsec_audit.log | grep "action:blocked"
```

### Whitelist IP (Emergency)
```nginx
# Add to forlock-custom-rules.conf
SecRule REMOTE_ADDR "@ipMatch 1.2.3.4" \
    "id:9999,phase:1,nolog,allow"
```

---

**Document Approval**:
- Security Lead: ___________________
- Infrastructure Lead: ___________________

**Next Review**: 2025-03-21 (3 months)
