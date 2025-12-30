# GDPR & KVKK Data Protection Compliance

**Document Version**: 1.0
**Last Updated**: 2025-12-30
**Regulations**:
- GDPR (EU General Data Protection Regulation)
- KVKK (Turkish Personal Data Protection Law)

---

## Overview

Forlock is designed with privacy by design and privacy by default principles, ensuring compliance with major data protection regulations.

**GDPR Compliance**: ✅ Full
**KVKK Compliance**: ✅ Full

---

## Data Protection Principles

### GDPR Article 5 / KVKK Article 4

| Principle | Implementation | Status |
|-----------|---------------|--------|
| **Lawfulness, fairness, transparency** | Clear privacy policy, consent management | ✅ |
| **Purpose limitation** | Data used only for password management | ✅ |
| **Data minimization** | Minimal data collection | ✅ |
| **Accuracy** | User-controlled data updates | ✅ |
| **Storage limitation** | Configurable retention, auto-deletion | ✅ |
| **Integrity and confidentiality** | AES-256-GCM encryption, access controls | ✅ |
| **Accountability** | Audit logging, documentation | ✅ |

---

## Data Subject Rights

### Rights Implementation

| Right | GDPR Article | KVKK Article | Implementation | Status |
|-------|--------------|--------------|----------------|--------|
| **Right to Access** | Art. 15 | Art. 11(1)(b) | Data export API, account settings | ✅ |
| **Right to Rectification** | Art. 16 | Art. 11(1)(c) | User can edit all personal data | ✅ |
| **Right to Erasure** | Art. 17 | Art. 11(1)(e) | Account deletion, vault purge | ✅ |
| **Right to Restrict Processing** | Art. 18 | Art. 11(1)(d) | Account suspension | ✅ |
| **Right to Data Portability** | Art. 20 | - | Export in standard formats | ✅ |
| **Right to Object** | Art. 21 | Art. 11(1)(f) | Opt-out mechanisms | ✅ |
| **Automated Decision Rights** | Art. 22 | Art. 11(1)(g) | No automated decisions | ✅ |

### Data Subject Request Process

```
1. User submits request (in-app or email)
       ↓
2. Identity verification (MFA required)
       ↓
3. Request logged in audit system
       ↓
4. Request processed within 30 days
       ↓
5. Response provided to user
       ↓
6. Action logged for compliance evidence
```

---

## Data Processing

### Personal Data Categories

| Category | Examples | Legal Basis | Retention |
|----------|----------|-------------|-----------|
| **Account Data** | Email, username | Contract (Art. 6(1)(b)) | Account lifetime |
| **Authentication Data** | Password hash, MFA | Contract + Legitimate Interest | Account lifetime |
| **Vault Data** | Passwords, secrets | Contract | User-controlled |
| **Audit Logs** | Activity records | Legitimate Interest | 3 years |
| **Technical Data** | IP, user agent | Legitimate Interest | 90 days |

### Special Categories (GDPR Art. 9)

Forlock does **NOT** process special category data:
- ❌ Racial/ethnic origin
- ❌ Political opinions
- ❌ Religious beliefs
- ❌ Trade union membership
- ❌ Genetic/biometric data
- ❌ Health data
- ❌ Sexual orientation

---

## Privacy by Design

### Zero-Knowledge Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     USER DEVICE                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  1. Master Password (never transmitted)          │   │
│  │  2. Key derivation (PBKDF2/Argon2)              │   │
│  │  3. Local encryption (AES-256-GCM)              │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────┘
                             │ Encrypted blob only
                             ▼
┌─────────────────────────────────────────────────────────┐
│                   FORLOCK SERVER                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  ❌ Cannot decrypt vault data                    │   │
│  │  ❌ Cannot see master password                   │   │
│  │  ❌ Cannot reset master password                 │   │
│  │  ✅ Stores encrypted blobs only                  │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Technical Measures (GDPR Art. 32)

| Measure | Implementation |
|---------|----------------|
| **Encryption at rest** | AES-256-GCM for all vault data |
| **Encryption in transit** | TLS 1.3 mandatory |
| **Pseudonymization** | User IDs instead of names in logs |
| **Access control** | RBAC + MFA |
| **Audit logging** | Tamper-proof logs |
| **Backup encryption** | GPG encrypted backups |

---

## Data Breach Notification

### GDPR Article 33-34 / KVKK Article 12

**Authority Notification**: Within 72 hours
**User Notification**: Without undue delay (if high risk)

### Breach Response Process

```
1. Breach detected
       ↓
2. Initial assessment (1-4 hours)
   - What data affected?
   - How many users?
   - Risk level?
       ↓
3. Containment (immediate)
   - Stop ongoing breach
   - Preserve evidence
       ↓
4. Authority notification (within 72 hours)
   - National DPA (GDPR)
   - KVKK (Turkey)
       ↓
5. User notification (if high risk)
   - Clear description
   - Recommendations
       ↓
6. Documentation
   - Timeline
   - Actions taken
   - Remediation
```

### Breach Notification Template

**To Data Protection Authority**:
```
Data Controller: [Organization name]
Contact DPO: [DPO contact]
Date of Awareness: [Date/Time]

Nature of Breach:
[Description of breach]

Categories of Data:
[List affected data types]

Number of Data Subjects:
[Approximate number]

Likely Consequences:
[Assessment of impact]

Measures Taken:
[Remediation steps]
```

---

## International Data Transfers

### Transfer Mechanisms

| Destination | Mechanism | Status |
|-------------|-----------|--------|
| **EU/EEA** | Adequate protection | ✅ No restrictions |
| **UK** | Adequacy decision | ✅ Valid until 2025 |
| **Switzerland** | Adequacy decision | ✅ No restrictions |
| **USA** | EU-US DPF | ✅ For DPF participants |
| **Other** | SCCs required | ⚠️ Case-by-case |

### Self-Hosted Option

Organizations can deploy Forlock on-premises to maintain full data sovereignty:
- Data never leaves organization's infrastructure
- No cross-border transfers
- Full control over data location

---

## Data Protection Impact Assessment (DPIA)

### When Required (GDPR Art. 35)

A DPIA is performed when processing is likely to result in high risk:
- ✅ Large-scale processing of sensitive data
- ✅ Systematic monitoring
- ✅ New technologies

### DPIA Summary

| Factor | Assessment |
|--------|------------|
| **Data processed** | Credentials (sensitive) |
| **Scale** | Potentially large |
| **Technology** | Zero-knowledge encryption |
| **Risk mitigation** | Encryption, access control, audit |
| **Residual risk** | Low (data encrypted, minimal exposure) |

---

## Data Protection Officer (DPO)

### DPO Responsibilities

- Monitor GDPR/KVKK compliance
- Advise on data protection matters
- Handle data subject requests
- Liaise with supervisory authorities
- Conduct training and awareness

### Contact

- **Email**: [dpo contact]
- **Response time**: Within 30 days

---

## KVKK-Specific Requirements

### Data Controller Registration

- **VERBIS Registration**: Required for Turkey operations
- **Registration Number**: [If applicable]

### KVKK Data Processing Conditions (Article 5)

| Condition | Applicable |
|-----------|------------|
| Explicit consent | ✅ For optional features |
| Legal obligation | ✅ Audit requirements |
| Contract performance | ✅ Service delivery |
| Legitimate interest | ✅ Security monitoring |
| Public interest | ❌ Not applicable |
| Vital interests | ❌ Not applicable |

### Cross-Border Transfer (KVKK Article 9)

Transfers outside Turkey require:
- Explicit consent, OR
- Adequate protection (KVKK-approved countries), OR
- Controller commitment letter

---

## Compliance Evidence

### Documentation Maintained

| Document | Purpose | Update Frequency |
|----------|---------|------------------|
| Privacy Policy | User transparency | Annual / On change |
| Data Processing Agreement | Controller obligations | On contract |
| DPIA | Risk assessment | On new processing |
| Breach Register | Incident tracking | On incident |
| Consent Records | Proof of consent | Continuous |
| DSR Log | Request tracking | Continuous |

### Audit Trail

All data processing activities are logged:
- What data accessed
- Who accessed it
- When accessed
- Why accessed (action type)

---

## Contact Information

### Data Protection Inquiries

- **General inquiries**: [privacy contact]
- **Data Subject Requests**: [dsr contact]
- **Breach Reporting**: [security contact]

### Supervisory Authorities

**GDPR (EU)**:
- Lead authority: [Relevant EU DPA]

**KVKK (Turkey)**:
- KVKK (Kişisel Verileri Koruma Kurumu)
- Website: https://www.kvkk.gov.tr

---

## Related Documents

- [Compliance Overview](OVERVIEW.md)
- [Security Architecture](../security/ARCHITECTURE.md)
- [Incident Response](../operations/INCIDENT_RESPONSE.md)
