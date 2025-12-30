# Forlock Incident Response Playbook

**Document Version**: 1.0
**Last Updated**: 2025-12-30
**Framework**: NIST SP 800-61 Rev. 2 (Computer Security Incident Handling Guide)
**Compliance**: ISO 27001:2022 A.16, SOC 2 CC7.4

---

## Table of Contents

1. [Overview](#1-overview)
2. [Incident Classification](#2-incident-classification)
3. [Response Team](#3-response-team)
4. [Incident Response Process](#4-incident-response-process)
5. [Playbooks by Incident Type](#5-playbooks-by-incident-type)
6. [Communication Templates](#6-communication-templates)
7. [Post-Incident Activities](#7-post-incident-activities)

---

## 1. Overview

### Purpose
This playbook provides standardized procedures for detecting, responding to, and recovering from security incidents affecting Forlock production systems.

### Scope
- Production environment
- User data and authentication systems
- API and frontend services
- Database and backup systems
- Third-party integrations

### Incident Response Phases (NIST SP 800-61)
1. **Preparation** - Tools, training, documentation
2. **Detection & Analysis** - Identify and assess incidents
3. **Containment** - Stop the bleeding
4. **Eradication** - Remove threat actor/malware
5. **Recovery** - Restore normal operations
6. **Post-Incident** - Lessons learned, improvements

---

## 2. Incident Classification

### Severity Levels

| Level | Definition | Response Time | Escalation |
|-------|-----------|---------------|------------|
| **P1 - Critical** | System-wide outage, active data breach, ransomware | **< 15 min** | Immediate (CEO, Security, Legal) |
| **P2 - High** | Partial outage, confirmed intrusion, DDoS attack | **< 1 hour** | Security Team, Management |
| **P3 - Medium** | Suspicious activity, potential breach, phishing campaign | **< 4 hours** | Security Team |
| **P4 - Low** | Security policy violation, minor config issue | **< 24 hours** | IT Team |

### Incident Types

| Type | Examples | Initial Playbook |
|------|----------|------------------|
| **Security Breach** | Unauthorized access, account takeover | [Playbook #1](#playbook-1-security-breach) |
| **Data Leak** | GDPR breach, exposed credentials | [Playbook #2](#playbook-2-data-leak) |
| **DDoS Attack** | Service unavailable, traffic spike | [Playbook #3](#playbook-3-ddos-attack) |
| **Ransomware** | Encrypted files, ransom demand | [Playbook #4](#playbook-4-ransomware) |
| **Insider Threat** | Malicious employee, privilege abuse | [Playbook #5](#playbook-5-insider-threat) |
| **Malware/Phishing** | Infected system, credential phishing | [Playbook #6](#playbook-6-malware--phishing) |

---

## 3. Response Team

### Incident Response Team (IRT)

| Role | Responsibilities |
|------|-----------------|
| **Incident Commander** | Overall coordination, decision making |
| **Security Lead** | Forensics, threat analysis, containment |
| **Infrastructure Lead** | System recovery, network isolation |
| **Database Admin** | Data integrity, backup restoration |
| **Communications Lead** | User notifications, PR, legal liaison |
| **Legal Counsel** | GDPR/KVKK compliance, law enforcement |

---

## 4. Incident Response Process

### Phase 1: Detection & Initial Assessment (0-15 minutes)

**Trigger Sources**:
- Security monitoring alerts
- Failed login spike detection
- User reports
- Path scanning detection
- External notification

**Immediate Actions**:
1. **Acknowledge alert**
2. **Initial triage**:
   ```bash
   # Quick health check
   ./scripts/maintenance/health-check.sh

   # View recent errors
   ./scripts/maintenance/logs.sh --errors

   # Check for suspicious activity in audit logs
   ```
3. **Classify incident** (P1-P4, incident type)
4. **Escalate if needed** (P1/P2 → Incident Commander)
5. **Open incident ticket**

### Phase 2: Containment (15 minutes - 1 hour)

**Goal**: Stop attacker progression, prevent further damage

**Short-term Containment** (Immediate):
- Isolate affected systems
- Block malicious IPs
- Revoke compromised credentials
- Disable compromised accounts

**Long-term Containment** (After analysis):
- Apply security patches
- Implement additional monitoring
- Strengthen access controls

### Phase 3: Eradication (1-4 hours)

**Goal**: Remove threat actor access, malware, backdoors

**Actions**:
1. Identify root cause
2. Remove malware/backdoors
3. Patch vulnerabilities
4. Reset all potentially compromised credentials
5. Verify attacker access is revoked

### Phase 4: Recovery (4-24 hours)

**Goal**: Restore normal operations safely

**Actions**:
1. Restore from clean backups (if needed)
2. Apply security updates
3. Verify data integrity
4. Enhanced monitoring (24-48 hours)
5. Gradual service restoration

### Phase 5: Post-Incident (1-7 days)

**Goal**: Learn and improve

**Activities**:
1. Post-Incident Review Meeting (within 72 hours)
2. Root Cause Analysis (RCA)
3. Timeline reconstruction
4. Lessons learned documentation
5. Update playbooks
6. Implement preventive measures

---

## 5. Playbooks by Incident Type

### Playbook #1: Security Breach (Unauthorized Access)

**Indicators**:
- Path scanning detection (>10 suspicious requests)
- Failed login attempts spike (>5 from same IP)
- Successful login from unusual location
- Unexpected admin actions in audit logs

#### Phase 1: Detection (0-15 min)

**Verify Incident**:
```bash
# Check active sessions in database
# Look for unusual IP addresses, timestamps, user agents

# Check recent admin actions in audit logs
# Look for Critical severity events
```

**Classify**:
- **P1**: Admin account compromised, data accessed
- **P2**: User account compromised, no data access
- **P3**: Failed attack attempt (no access gained)

#### Phase 2: Containment (15-60 min)

1. **Block attacker IP** via firewall or application blocklist
2. **Revoke compromised sessions**
3. **Disable compromised account**
4. **Preserve evidence** (export logs before rotation)

#### Phase 3: Investigation (1-4 hours)

1. Identify attack vector (brute force? credential stuffing?)
2. Determine data accessed
3. Check for lateral movement
4. IP reputation check

#### Phase 4: Eradication

1. Patch vulnerability
2. Reset credentials for affected users
3. Rotate system secrets (if admin compromised)

#### Phase 5: Recovery

1. Restore affected data (if modified)
2. Unlock affected accounts
3. Enhanced monitoring (48 hours)
4. User notification

---

### Playbook #2: Data Leak (GDPR/KVKK Breach)

**Indicators**:
- Exposed credentials in public repository
- Database dump leaked online
- Unauthorized data export
- Large vault download

#### GDPR/KVKK Requirements
- **Notification**: 72 hours to Data Protection Authority
- **User Notification**: Without undue delay if high risk

#### Immediate Actions

1. **Stop ongoing leak** (takedown requests, credential rotation)
2. **Assess scope** (what data? how many users?)
3. **Rotate all secrets**
4. **Force password reset for all users**
5. **Invalidate all sessions**

#### User Notification Template
```
Subject: Important Security Notice - Action Required

Dear Forlock User,

We are writing to inform you of a security incident that may have
affected your account.

WHAT HAPPENED:
[Brief description]

WHAT DATA WAS EXPOSED:
[List affected data types]

WHAT WE'RE DOING:
- Forced password reset for all users
- Enhanced security monitoring
- Notified authorities (GDPR/KVKK)

WHAT YOU SHOULD DO:
1. Reset your password immediately
2. Enable MFA (Multi-Factor Authentication)
3. Review account activity
4. Be alert for phishing attempts

Questions: [support email]

The Forlock Security Team
```

---

### Playbook #3: DDoS Attack

**Indicators**:
- Traffic spike (10x+ normal)
- Service slowness/unavailability
- Nginx connection errors
- High CPU/memory usage

#### Quick Response (0-30 min)

1. **Identify attack type**:
   ```bash
   # Check top requesting IPs
   ./scripts/maintenance/logs.sh | grep -E "^[0-9]" | sort | uniq -c | sort -rn | head -20
   ```

2. **Immediate mitigation**:
   - Enable aggressive rate limiting
   - Block top attacking IPs
   - Enable CDN "Under Attack" mode (if using Cloudflare)

3. **Scale infrastructure** (if cloud):
   - Add more nodes
   - Load balancer distribution

---

### Playbook #4: Ransomware

**Indicators**:
- Files encrypted
- Ransom note present
- Processes consuming high CPU
- Cannot access files

#### CRITICAL Actions (0-5 min)

1. **DO NOT PAY RANSOM**
2. **Isolate immediately**:
   ```bash
   # Disconnect from network
   ip link set eth0 down
   ```
3. **Alert team**: P1 - CRITICAL
4. **Preserve evidence**: DO NOT reboot

#### Recovery
1. Restore from clean backups
2. Identify ransomware variant
3. Check decryption tools (nomoreransom.org)
4. Rebuild affected systems from scratch
5. Report to law enforcement

---

### Playbook #5: Insider Threat

**Indicators**:
- Unusual admin activity outside business hours
- Large data export by employee
- Access to unauthorized resources
- Disgruntled employee behavior

#### Investigation (Sensitive - Involve HR/Legal)

1. **Covert monitoring** of suspect activity
2. **Coordinate with HR/Legal** before confrontation
3. **Prepare termination/suspension plan**
4. **Disable access** (when authorized)

---

### Playbook #6: Malware / Phishing

**Indicators**:
- Phishing email reported
- Malware detected on workstation
- Suspicious process running

#### Response

1. **Isolate affected system**
2. **Credential reset** (if entered on phishing site)
3. **Email analysis** (headers, sender, links)
4. **User awareness training**

---

## 6. Communication Templates

### Internal Alert Template

```
SUBJECT: [P1] SECURITY INCIDENT - Immediate Action Required

INCIDENT: [Type - e.g., Security Breach]
SEVERITY: P1 - Critical
DETECTED: [Timestamp UTC]
STATUS: [Containment in progress]

SUMMARY:
[Brief description of incident]

IMMEDIATE ACTIONS:
- [Action 1]
- [Action 2]

IMPACT:
- [Number] accounts affected
- [Data exposure status]
- [Service status]

NEXT STEPS:
- [Step 1]
- [Step 2]

IR LEAD: [Name]
TICKET: [Incident ID]
```

---

## 7. Post-Incident Activities

### Post-Incident Review Template

```markdown
# Incident Review: [Incident ID]

## Incident Summary
- **Date**: [Date]
- **Severity**: [P1-P4]
- **Type**: [Incident type]
- **Duration**: [Detection to recovery]

## Timeline
| Time (UTC) | Event |
|------------|-------|
| HH:MM | [Event description] |

## Root Cause
- [Primary cause]
- [Contributing factors]

## Impact
- [Users affected]
- [Data exposure]
- [Service downtime]

## Response Effectiveness
- Detection: [Good/Needs improvement]
- Containment: [Good/Needs improvement]
- Communication: [Good/Needs improvement]

## Lessons Learned
1. [Lesson 1]
2. [Lesson 2]

## Action Items
- [ ] [Action] (Owner, Due date)
```

---

## Quick Reference

### Critical Commands

```bash
# Block IP via firewall
ufw insert 1 deny from X.X.X.X to any

# View security logs
./scripts/maintenance/logs.sh --errors

# Export logs for forensics
./scripts/maintenance/logs.sh --export

# Health check
./scripts/maintenance/health-check.sh
```

### Escalation Flowchart

```
Incident Detected
       ↓
   Classify (P1-P4)
       ↓
    P1/P2? ──No──→ IT Team handles (P3/P4)
       ↓ Yes
Incident Commander
       ↓
 Response Team Mobilized
       ↓
  Execute Playbook
       ↓
  Containment → Eradication → Recovery
       ↓
 Post-Incident Review
       ↓
   Update Playbook
```

---

### External Resources

| Resource | Purpose | URL |
|----------|---------|-----|
| **AbuseIPDB** | IP reputation | https://www.abuseipdb.com/ |
| **VirusTotal** | File/URL analysis | https://www.virustotal.com/ |
| **Have I Been Pwned** | Credential leak check | https://haveibeenpwned.com/ |
| **No More Ransom** | Ransomware decryption | https://www.nomoreransom.org/ |
| **NIST SP 800-61** | IR framework | https://csrc.nist.gov/ |

---

**Document Approval**:
- Incident Response Lead: ___________________
- Security Lead: ___________________

**Next Review**: [6 months from approval]
**Training Schedule**: Quarterly tabletop exercises
