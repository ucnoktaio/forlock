# Forlock Security Architecture

**Document Version**: 1.0
**Last Updated**: 2025-12-30

---

## Overview

Forlock implements a defense-in-depth security architecture with multiple layers of protection. This document describes the security controls and architecture.

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                      NETWORK LAYER                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Firewall (UFW) → Rate Limiting → TLS 1.3 → WAF        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Authentication → Authorization → Input Validation      │   │
│  │  Session Management → CSRF Protection → Rate Limiting   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                       DATA LAYER                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Encryption at Rest (AES-256) → Database Security       │   │
│  │  Key Management (HSM/Vault) → Backup Encryption         │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    MONITORING LAYER                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Audit Logging → SIEM Integration → Alerting            │   │
│  │  Security Dashboard → Anomaly Detection                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Zero-Knowledge Architecture

### Client-Side Encryption

All sensitive vault data is encrypted on the client before transmission to the server.

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT DEVICE                             │
│                                                                  │
│  User Input: "my-secret-password"                               │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────┐               │
│  │  Master Password + Salt                      │               │
│  │       │                                      │               │
│  │       ▼                                      │               │
│  │  PBKDF2/Argon2id (100,000+ iterations)      │               │
│  │       │                                      │               │
│  │       ▼                                      │               │
│  │  256-bit Encryption Key                      │               │
│  │       │                                      │               │
│  │       ▼                                      │               │
│  │  AES-256-GCM Encryption                      │               │
│  │       │                                      │               │
│  │       ▼                                      │               │
│  │  Encrypted Blob (ciphertext + IV + tag)     │               │
│  └─────────────────────────────────────────────┘               │
│       │                                                          │
└───────┼──────────────────────────────────────────────────────────┘
        │
        ▼ (Only encrypted data sent to server)
┌─────────────────────────────────────────────────────────────────┐
│                       FORLOCK SERVER                             │
│                                                                  │
│  ❌ Cannot decrypt data (no master password)                    │
│  ❌ Cannot derive encryption key                                │
│  ✅ Stores encrypted blobs only                                 │
│  ✅ Provides secure sync and sharing                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Hierarchy

```
Master Password (user-provided, never stored)
       │
       ▼
  Key Derivation (Argon2id)
       │
       ├──► Vault Key (AES-256-GCM)
       │         │
       │         └──► Per-Item Keys
       │
       └──► Authentication Key (for server auth)
```

---

## Network Security

### Perimeter Defense

| Layer | Control | Purpose |
|-------|---------|---------|
| Firewall | UFW | Block unauthorized ports |
| Rate Limiting | Nginx | Prevent brute force, DDoS |
| TLS | 1.3 only | Encrypt all traffic |
| WAF | ModSecurity | OWASP Top 10 protection |

### TLS Configuration

```nginx
ssl_protocols TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
```

### Network Segmentation

```
┌─────────────────────────────────────────┐
│              PUBLIC NETWORK              │
│           (Internet-facing)              │
│  ┌─────────────────────────────┐        │
│  │      Nginx (80/443)         │        │
│  └─────────────────────────────┘        │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│            INTERNAL NETWORK              │
│        (Docker bridge network)           │
│                                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │   API   │  │Frontend │  │RabbitMQ │ │
│  │  :8080  │  │  :80    │  │  :5672  │ │
│  └────┬────┘  └─────────┘  └─────────┘ │
│       │                                  │
│  ┌────▼────┐  ┌─────────┐               │
│  │PostgreSQL│ │  Redis  │               │
│  │  :5432  │  │  :6379  │               │
│  └─────────┘  └─────────┘               │
│                                          │
│  (Not exposed to internet)               │
└──────────────────────────────────────────┘
```

---

## Authentication Security

### Authentication Methods

| Method | Security Level | Use Case |
|--------|---------------|----------|
| Local (email/password) | High (+ MFA) | Default |
| LDAP/Active Directory | High | Enterprise |
| OIDC (OAuth 2.0) | High | SSO |
| FIDO2/WebAuthn | Highest | Hardware keys |

### Password Security

| Control | Implementation |
|---------|----------------|
| Hashing | Argon2id (memory-hard) |
| Minimum length | 12 characters |
| Complexity | Upper, lower, number, special |
| Breach detection | Have I Been Pwned API |
| Account lockout | 5 failed attempts → 15 min lockout |

### Multi-Factor Authentication

| Factor | Type | Details |
|--------|------|---------|
| TOTP | Something you have | 6-digit codes (RFC 6238) |
| FIDO2 | Something you have | Hardware security keys |
| Backup codes | Recovery | 10 single-use codes |

### Session Security

| Control | Implementation |
|---------|----------------|
| Token type | JWT (access) + Refresh tokens |
| Access token lifetime | 15 minutes |
| Refresh token lifetime | 7 days |
| Secure storage | HttpOnly, Secure, SameSite |
| Revocation | Immediate invalidation |

---

## Authorization Security

### Role-Based Access Control (RBAC)

```
┌─────────────────────────────────────────────────────────────┐
│                        ROLES                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────┐   │
│  │  Owner  │  │  Admin  │  │ Manager │  │    User     │   │
│  │(Full)   │  │(Manage) │  │(Limited)│  │(Read/Write) │   │
│  └────┬────┘  └────┬────┘  └────┬────┘  └──────┬──────┘   │
│       │           │            │               │           │
│       └───────────┴────────────┴───────────────┘           │
│                          │                                  │
│                          ▼                                  │
│                   PERMISSIONS                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  vault:read, vault:write, vault:share, vault:delete │   │
│  │  user:manage, settings:edit, audit:view             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Permission-Based Access Control (PBAC)

Fine-grained permissions for vault items:
- Read
- Write
- Share
- Delete
- Manage (full control)

### Conditional Access

| Condition | Action |
|-----------|--------|
| Untrusted IP | Require MFA |
| New device | Require email verification |
| Off-hours access | Additional verification |
| High-risk score | Step-up authentication |

---

## Data Security

### Encryption Standards

| Data Type | Algorithm | Key Size |
|-----------|-----------|----------|
| Vault items | AES-256-GCM | 256-bit |
| File attachments | AES-256-GCM | 256-bit |
| Backup data | GPG (AES-256) | 256-bit |
| TLS | TLS 1.3 | 256-bit |
| Signatures | ECDSA | P-256 |

### Key Management

| Key Type | Storage | Rotation |
|----------|---------|----------|
| Master Password | Client only (never stored) | User-controlled |
| Vault Keys | Encrypted in database | On password change |
| Server Keys | HSM or Vault | 90 days |
| TLS Certificates | File system | 90 days |

### Database Security

| Control | Implementation |
|---------|----------------|
| Connection encryption | SSL required |
| Access control | Separate DB user |
| Query parameterization | Prevents SQL injection |
| Audit logging | All queries logged |

---

## Monitoring & Detection

### Audit Logging

All security-relevant events are logged with:
- Timestamp
- User ID
- IP address
- User agent
- Action performed
- Resource affected
- Result (success/failure)

### Tamper-Proof Logging

```
┌─────────────────────────────────────────────────────────────┐
│                    AUDIT LOG CHAIN                           │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│  │ Entry 1  │───►│ Entry 2  │───►│ Entry 3  │───► ...     │
│  │          │    │          │    │          │              │
│  │ Hash(N-1)│    │ Hash(N-1)│    │ Hash(N-1)│              │
│  │ Data     │    │ Data     │    │ Data     │              │
│  │ Signature│    │ Signature│    │ Signature│              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                                              │
│  Any modification breaks the chain = tampering detected     │
└─────────────────────────────────────────────────────────────┘
```

### Security Alerting

| Event | Severity | Action |
|-------|----------|--------|
| Failed login (5+) | Medium | Auto-lockout + alert |
| Path scanning detected | High | IP block + alert |
| Admin action | Info | Logged |
| Data export | Medium | Logged + notification |
| MFA disabled | High | Email notification |

### Security Dashboard

Real-time visibility into:
- Active sessions
- Failed authentication attempts
- Geographic distribution
- Unusual activity patterns
- System health metrics

---

## Threat Protection

### OWASP Top 10 Mitigation

| Threat | Mitigation |
|--------|------------|
| A01: Broken Access Control | RBAC, PBAC, authorization checks |
| A02: Cryptographic Failures | AES-256-GCM, TLS 1.3 |
| A03: Injection | Parameterized queries, input validation |
| A04: Insecure Design | Security by design, threat modeling |
| A05: Security Misconfiguration | Hardened defaults, IaC |
| A06: Vulnerable Components | Dependency scanning |
| A07: Authentication Failures | MFA, secure sessions |
| A08: Data Integrity Failures | Signed updates, integrity checks |
| A09: Logging Failures | Comprehensive audit logging |
| A10: SSRF | Request validation, allowlisting |

### Attack Detection

| Attack Type | Detection Method |
|-------------|-----------------|
| Brute force | Login rate limiting, lockout |
| Credential stuffing | Breach detection, risk scoring |
| Path traversal | Path validation, WAF |
| SQL injection | Parameterized queries, WAF |
| XSS | Content-Security-Policy, encoding |
| DDoS | Rate limiting, CDN protection |

---

## Security Testing

### Continuous Security

| Test Type | Frequency | Tool |
|-----------|-----------|------|
| Dependency scan | Daily | Dependabot, Snyk |
| SAST | On commit | CodeQL |
| Container scan | On build | Trivy |
| DAST | Weekly | OWASP ZAP |
| Penetration test | Annual | External vendor |

---

## Related Documents

- [Encryption Details](ENCRYPTION.md)
- [Access Control](ACCESS_CONTROL.md)
- [Compliance Overview](../compliance/OVERVIEW.md)
- [Incident Response](../operations/INCIDENT_RESPONSE.md)
