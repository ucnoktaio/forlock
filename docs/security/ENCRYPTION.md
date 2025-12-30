# Forlock Encryption & Key Management

**Document Version**: 1.0
**Last Updated**: 2025-12-30

---

## Overview

Forlock uses industry-standard cryptographic algorithms and a zero-knowledge architecture to protect user data. This document describes the encryption mechanisms and key management practices.

---

## Cryptographic Algorithms

### Symmetric Encryption

| Purpose | Algorithm | Key Size | Mode |
|---------|-----------|----------|------|
| Vault data | AES | 256-bit | GCM |
| File attachments | AES | 256-bit | GCM |
| Backups | AES | 256-bit | GCM |

**Why AES-256-GCM?**
- NIST approved
- Provides confidentiality + integrity (AEAD)
- Hardware acceleration (AES-NI)
- No padding oracle vulnerabilities

### Password Hashing

| Purpose | Algorithm | Parameters |
|---------|-----------|------------|
| Master password | Argon2id | Memory: 64MB, Iterations: 3, Parallelism: 4 |
| Account password | Argon2id | Memory: 64MB, Iterations: 3, Parallelism: 4 |
| API keys | HMAC-SHA256 | N/A |

**Why Argon2id?**
- Winner of Password Hashing Competition (PHC)
- Memory-hard (resists GPU attacks)
- Time-hard (resists ASIC attacks)
- Side-channel resistant (id variant)

### Asymmetric Encryption

| Purpose | Algorithm | Key Size |
|---------|-----------|----------|
| Digital signatures | ECDSA | P-256 |
| Key exchange | ECDH | P-256 |
| Audit log signing | ECDSA | P-256 |

### Other Cryptographic Functions

| Purpose | Algorithm |
|---------|-----------|
| Key derivation | PBKDF2-SHA256 / Argon2id |
| MAC | HMAC-SHA256 |
| Random generation | CSPRNG |
| Hashing | SHA-256, SHA-384 |

---

## Key Hierarchy

### Master Password Derivation

```
Master Password (user input)
       │
       ├── Salt (random, per-user)
       │
       ▼
  Argon2id KDF
  (m=64MB, t=3, p=4)
       │
       ▼
  Derived Key (256-bit)
       │
       ├──► Vault Key (for encrypting vault items)
       │
       └──► Auth Key (for server authentication)
```

### Vault Encryption Keys

```
┌─────────────────────────────────────────────────────────────┐
│                    KEY HIERARCHY                             │
│                                                              │
│  User Master Password                                        │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Master Key (derived via Argon2id)                   │   │
│  │  - Never stored, derived on-demand                   │   │
│  └─────────────────────────────────────────────────────┘   │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Vault Key (encrypted with Master Key)               │   │
│  │  - Stored in database (encrypted)                    │   │
│  │  - Rotates on password change                        │   │
│  └─────────────────────────────────────────────────────┘   │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Item Keys (encrypted with Vault Key)                │   │
│  │  - Per-item encryption                               │   │
│  │  - Enables granular sharing                          │   │
│  └─────────────────────────────────────────────────────┘   │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Encrypted Data (passwords, notes, etc.)             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Encryption Flows

### Saving a Vault Item

```
1. User creates/edits item
       │
       ▼
2. Generate random IV (96-bit)
       │
       ▼
3. Derive item key (if new item)
       │
       ▼
4. Encrypt plaintext:
   ciphertext = AES-256-GCM(key, IV, plaintext, AAD)
       │
       ▼
5. Store: IV || ciphertext || auth_tag
       │
       ▼
6. Send encrypted blob to server
```

### Decrypting a Vault Item

```
1. Receive encrypted blob from server
       │
       ▼
2. Parse: IV || ciphertext || auth_tag
       │
       ▼
3. Derive item key from vault key
       │
       ▼
4. Decrypt:
   plaintext = AES-256-GCM-Decrypt(key, IV, ciphertext, AAD)
       │
       ▼
5. Verify auth_tag (integrity check)
       │
       ▼
6. Return plaintext to user
```

### Password Change

```
1. User provides new password
       │
       ▼
2. Derive new Master Key
       │
       ▼
3. Decrypt Vault Key with old Master Key
       │
       ▼
4. Re-encrypt Vault Key with new Master Key
       │
       ▼
5. Update stored Vault Key
       │
       ▼
6. All item keys remain unchanged (still encrypted with Vault Key)
```

---

## Key Storage

### Client-Side Keys

| Key | Storage | Persistence |
|-----|---------|-------------|
| Master Password | Memory only | Session |
| Derived Keys | Memory only | Session |
| Decrypted Items | Memory only | View duration |

### Server-Side Keys

| Key | Storage | Protection |
|-----|---------|------------|
| Encrypted Vault Keys | PostgreSQL | User authentication |
| Encrypted Item Keys | PostgreSQL | Vault Key encryption |
| Server Signing Keys | File / HSM | File permissions / HSM |
| TLS Certificates | File system | File permissions |

---

## Key Management

### Key Rotation

| Key Type | Rotation Trigger | Process |
|----------|-----------------|---------|
| Master Password | User-initiated | Re-encrypt vault key |
| Vault Key | Password change | Automatic |
| Item Keys | Never (per-item) | N/A |
| Server Keys | 90 days | Manual rotation |
| TLS Certificates | 90 days | Auto-renewal |

### Key Recovery

**Master Password Recovery: NOT POSSIBLE**

Due to zero-knowledge architecture:
- Server cannot reset master password
- Server cannot decrypt vault data
- Only user-held recovery methods work

**Available Recovery Methods**:
1. Password hint (user-configured)
2. Emergency access (trusted contacts)
3. Organization recovery key (enterprise)

### Key Destruction

| Scenario | Action |
|----------|--------|
| Account deletion | All encrypted data permanently deleted |
| Session logout | Memory keys cleared |
| Item deletion | Item key and data removed |

---

## Hardware Security Module (HSM) Support

### Supported HSM Types

| Type | Use Case |
|------|----------|
| AWS CloudHSM | Cloud deployment |
| Azure Dedicated HSM | Azure deployment |
| HashiCorp Vault | Self-hosted |
| YubiHSM | On-premise |
| Software HSM | Development |

### HSM-Protected Keys

When HSM is enabled:
- Server signing keys stored in HSM
- Key operations performed in HSM
- Keys never exposed in plaintext

---

## Cryptographic Boundaries

### What Is Encrypted

| Data | Encryption | Location |
|------|------------|----------|
| Passwords | AES-256-GCM | Client + Database |
| Secure notes | AES-256-GCM | Client + Database |
| File attachments | AES-256-GCM | Client + Database |
| Credit cards | AES-256-GCM | Client + Database |
| API credentials | AES-256-GCM | Client + Database |

### What Is NOT Encrypted (Metadata)

| Data | Reason |
|------|--------|
| Email address | Required for authentication |
| Vault item names | Optional (can be encrypted) |
| Timestamps | Required for sync |
| Organization membership | Required for access control |

### Transport Encryption

All network traffic encrypted with:
- TLS 1.3 (preferred)
- TLS 1.2 (minimum)
- Perfect Forward Secrecy (ECDHE)

---

## Compliance Mapping

| Requirement | Implementation |
|-------------|----------------|
| NIST SP 800-57 | Key management lifecycle |
| NIST SP 800-131A | Algorithm selection |
| FIPS 140-2 | FIPS-validated algorithms available |
| PCI DSS 3.4 | Strong cryptography for cardholder data |
| GDPR Art. 32 | Encryption as technical measure |

---

## Cryptographic Agility

Forlock is designed to support algorithm upgrades:

| Component | Current | Upgrade Path |
|-----------|---------|--------------|
| Symmetric encryption | AES-256-GCM | AES-256-GCM-SIV |
| Key derivation | Argon2id | Argon2id (param upgrade) |
| Signatures | ECDSA P-256 | Ed25519 |
| TLS | 1.3 | 1.3+ |

---

## Security Considerations

### Known Attack Mitigations

| Attack | Mitigation |
|--------|------------|
| Brute force (master password) | Argon2id with high params |
| Dictionary attack | Breach detection, password policy |
| Rainbow tables | Unique salts per user |
| Side-channel | Constant-time operations |
| Quantum computing | Post-quantum roadmap |

### Best Practices

1. **Use strong master passwords** (16+ characters)
2. **Enable MFA** for additional protection
3. **Use hardware keys** (FIDO2) when possible
4. **Don't reuse passwords** across services
5. **Regular security reviews** of encryption implementation

---

## Related Documents

- [Security Architecture](ARCHITECTURE.md)
- [Access Control](ACCESS_CONTROL.md)
- [Compliance Overview](../compliance/OVERVIEW.md)
