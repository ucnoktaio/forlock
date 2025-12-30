# Forlock Documentation

**Enterprise Password Manager - Technical & Compliance Documentation**

---

## Quick Links

| Category | Document | Description |
|----------|----------|-------------|
| **Deployment** | [Single Node](SINGLE_NODE.md) | Docker Compose deployment |
| | [Docker Swarm](SWARM.md) | High-availability deployment |
| | [Kubernetes](KUBERNETES.md) | K8s deployment |
| **Operations** | [Disaster Recovery](operations/DISASTER_RECOVERY.md) | RTO/RPO, backup procedures |
| | [Incident Response](operations/INCIDENT_RESPONSE.md) | Security incident playbooks |
| | [Maintenance](operations/MAINTENANCE.md) | Routine maintenance guide |
| **Security** | [Architecture](security/ARCHITECTURE.md) | Security architecture overview |
| | [Encryption](security/ENCRYPTION.md) | Encryption & key management |
| | [Access Control](security/ACCESS_CONTROL.md) | Authentication & authorization |
| **Compliance** | [Overview](compliance/OVERVIEW.md) | Compliance status summary |
| | [ISO 27001](compliance/ISO_27001.md) | ISO 27001:2022 controls |
| | [NIST CSF](compliance/NIST_CSF.md) | NIST framework mapping |
| | [GDPR/KVKK](compliance/GDPR_KVKK.md) | Data protection compliance |
| **Guides** | [WAF Deployment](guides/WAF_DEPLOYMENT.md) | ModSecurity WAF setup |
| | [SIEM Integration](guides/SIEM_INTEGRATION.md) | Graylog logging setup |
| | [Vault Integration](guides/VAULT_INTEGRATION.md) | HashiCorp Vault setup |

---

## Compliance Status

| Standard | Status | Coverage |
|----------|--------|----------|
| **ISO 27001:2022** | ✅ Compliant | 95% |
| **NIST CSF** | ✅ Tier 2-3 | 85% |
| **GDPR** | ✅ Compliant | Full |
| **KVKK** | ✅ Compliant | Full |
| **SOC 2 Type II** | 🔄 In Progress | - |

---

## Security Highlights

### Zero-Knowledge Architecture
- Client-side encryption (AES-256-GCM)
- Server never sees plaintext data
- Master password never transmitted

### Authentication
- Multi-factor authentication (TOTP, FIDO2/WebAuthn)
- LDAP/Active Directory integration
- OIDC/OAuth 2.0 SSO

### Audit & Compliance
- Tamper-proof audit logs (cryptographic chaining)
- Real-time security monitoring
- Comprehensive access controls (RBAC + PBAC)

---

## Documentation Structure

```
docs/
├── README.md                    # This file
├── SINGLE_NODE.md              # Single server deployment
├── SWARM.md                    # Docker Swarm HA
├── KUBERNETES.md               # Kubernetes deployment
│
├── operations/                 # Operational procedures
│   ├── DISASTER_RECOVERY.md    # DR plan (RTO 4h, RPO 1h)
│   ├── INCIDENT_RESPONSE.md    # Security incident playbooks
│   └── MAINTENANCE.md          # Routine maintenance
│
├── compliance/                 # Compliance documentation
│   ├── OVERVIEW.md             # Compliance summary
│   ├── ISO_27001.md            # ISO 27001:2022 controls
│   ├── NIST_CSF.md             # NIST CSF mapping
│   └── GDPR_KVKK.md            # Data protection
│
├── security/                   # Security documentation
│   ├── ARCHITECTURE.md         # Security architecture
│   ├── ENCRYPTION.md           # Encryption details
│   └── ACCESS_CONTROL.md       # Auth & authorization
│
└── guides/                     # Technical guides
    ├── WAF_DEPLOYMENT.md       # ModSecurity WAF
    ├── SIEM_INTEGRATION.md     # Graylog setup
    └── VAULT_INTEGRATION.md    # HashiCorp Vault
```

---

## Recovery Objectives

| Metric | Target | Details |
|--------|--------|---------|
| **RTO** (Recovery Time Objective) | 4 hours | Maximum acceptable downtime |
| **RPO** (Recovery Point Objective) | 1 hour | Maximum acceptable data loss |
| **MTD** (Maximum Tolerable Downtime) | 24 hours | Business viability threshold |

---

## Support

For technical support and inquiries:

- **Documentation Issues**: [GitHub Issues](https://github.com/ucnoktaio/forlock/issues)
- **Security Concerns**: security@ucnokta.io
- **Compliance Questions**: compliance@ucnokta.io

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial documentation package |

---

**Document Classification**: CONFIDENTIAL
