# Forlock Access Control

**Document Version**: 1.0
**Last Updated**: 2025-12-30

---

## Overview

Forlock implements multiple layers of access control to ensure that users can only access resources they are authorized to use. This document describes the authentication, authorization, and session management mechanisms.

---

## Authentication

### Authentication Methods

| Method | Description | Security Level |
|--------|-------------|----------------|
| **Local Authentication** | Email + password | Standard (+ MFA) |
| **LDAP/Active Directory** | Enterprise directory | High |
| **OIDC/OAuth 2.0** | Single Sign-On | High |
| **FIDO2/WebAuthn** | Hardware security keys | Highest |

### Local Authentication

```
┌─────────────────────────────────────────────────────────────┐
│                  LOGIN FLOW                                  │
│                                                              │
│  1. User enters email + password                            │
│       │                                                      │
│       ▼                                                      │
│  2. Password hashed (Argon2id)                              │
│       │                                                      │
│       ▼                                                      │
│  3. Compare with stored hash                                 │
│       │                                                      │
│       ├─── Failed: Increment attempt counter                 │
│       │            │                                         │
│       │            └── 5 failures: Lock account (15 min)    │
│       │                                                      │
│       └─── Success: Check MFA requirement                   │
│                │                                             │
│                ├── MFA required: Prompt for code            │
│                │         │                                   │
│                │         └── Verify TOTP/FIDO2              │
│                │                                             │
│                └── No MFA: Issue tokens                     │
│                                                              │
│  4. Return access_token + refresh_token                     │
└─────────────────────────────────────────────────────────────┘
```

### Password Requirements

| Requirement | Value |
|-------------|-------|
| Minimum length | 12 characters |
| Complexity | Upper, lower, number, special |
| Breach detection | Have I Been Pwned check |
| Password history | 5 previous passwords |
| Expiration | Optional (enterprise) |

### Multi-Factor Authentication (MFA)

#### TOTP (Time-based One-Time Password)

- **Standard**: RFC 6238
- **Algorithm**: HMAC-SHA1
- **Digits**: 6
- **Period**: 30 seconds
- **Backup codes**: 10 single-use codes

#### FIDO2/WebAuthn

- **Protocol**: WebAuthn Level 2
- **Authenticators**: Hardware keys (YubiKey, Titan)
- **User verification**: Required
- **Resident keys**: Supported

### Enterprise Authentication

#### LDAP/Active Directory

```
┌─────────────────────────────────────────────────────────────┐
│                  LDAP AUTHENTICATION                         │
│                                                              │
│  1. User enters domain credentials                          │
│       │                                                      │
│       ▼                                                      │
│  2. Bind to LDAP server                                     │
│       │                                                      │
│       ▼                                                      │
│  3. Search for user DN                                       │
│       │                                                      │
│       ▼                                                      │
│  4. Verify password against LDAP                            │
│       │                                                      │
│       ▼                                                      │
│  5. Sync group memberships                                   │
│       │                                                      │
│       ▼                                                      │
│  6. Create/update local account                             │
│       │                                                      │
│       ▼                                                      │
│  7. Issue Forlock tokens                                     │
└─────────────────────────────────────────────────────────────┘
```

#### OIDC/OAuth 2.0

Supported providers:
- Azure AD
- Okta
- Auth0
- Google Workspace
- Keycloak
- Generic OIDC

---

## Authorization

### Role-Based Access Control (RBAC)

#### Built-in Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| **Owner** | Organization creator | Full control |
| **Admin** | Organization administrator | Manage users, settings |
| **Manager** | Collection manager | Manage collection items |
| **User** | Standard user | Read/write assigned items |
| **Viewer** | Read-only user | View assigned items only |

#### Role Hierarchy

```
Owner
  │
  ├── Admin
  │     │
  │     ├── Manager
  │     │     │
  │     │     └── User
  │     │           │
  │     │           └── Viewer
  │     │
  │     └── (Custom roles)
  │
  └── (Full control)
```

### Permission-Based Access Control (PBAC)

#### Permission Types

| Permission | Description |
|------------|-------------|
| `vault:read` | View vault items |
| `vault:write` | Create/edit vault items |
| `vault:share` | Share vault items |
| `vault:delete` | Delete vault items |
| `vault:manage` | Full vault control |
| `user:read` | View users |
| `user:manage` | Manage users |
| `settings:read` | View organization settings |
| `settings:edit` | Edit organization settings |
| `audit:view` | View audit logs |
| `reports:view` | View reports |

#### Permission Assignment

```
┌─────────────────────────────────────────────────────────────┐
│                PERMISSION EVALUATION                         │
│                                                              │
│  Request: User wants to edit Vault Item X                   │
│       │                                                      │
│       ▼                                                      │
│  1. Check user's role permissions                           │
│       │                                                      │
│       ▼                                                      │
│  2. Check item-level permissions                            │
│       │                                                      │
│       ▼                                                      │
│  3. Check collection membership                             │
│       │                                                      │
│       ▼                                                      │
│  4. Check organization policies                             │
│       │                                                      │
│       ▼                                                      │
│  5. Apply conditional access rules                          │
│       │                                                      │
│       ▼                                                      │
│  Result: Allow or Deny                                       │
└─────────────────────────────────────────────────────────────┘
```

### Conditional Access

#### Access Conditions

| Condition | Trigger | Action |
|-----------|---------|--------|
| **IP-based** | Untrusted IP range | Require MFA |
| **Device-based** | New/unknown device | Email verification |
| **Time-based** | Off-hours access | Additional verification |
| **Risk-based** | High risk score | Block or step-up |
| **Location-based** | Impossible travel | Require verification |

#### Risk Scoring (19 Factors)

| Category | Factors |
|----------|---------|
| **Login patterns** | Time, frequency, location |
| **Device** | New device, fingerprint |
| **Network** | IP reputation, VPN, Tor |
| **Behavior** | Unusual actions, data export |
| **Account** | Age, MFA status, breach exposure |

---

## Session Management

### Token Types

| Token | Lifetime | Purpose |
|-------|----------|---------|
| **Access Token** | 15 minutes | API authorization |
| **Refresh Token** | 7 days | Obtain new access tokens |
| **ID Token** | N/A (OIDC) | User identity claims |

### Token Security

| Control | Implementation |
|---------|----------------|
| Storage | HttpOnly, Secure cookies |
| Transmission | TLS only |
| Signing | HMAC-SHA256 |
| Revocation | Immediate (Redis blacklist) |
| Refresh rotation | Single-use refresh tokens |

### Session Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                 SESSION LIFECYCLE                            │
│                                                              │
│  Login                                                       │
│    │                                                         │
│    ▼                                                         │
│  Create Session                                              │
│    │  - Generate tokens                                      │
│    │  - Record device fingerprint                           │
│    │  - Log audit event                                      │
│    │                                                         │
│    ▼                                                         │
│  Active Session                                              │
│    │  - Access token expires (15 min)                       │
│    │  - Refresh token used to renew                         │
│    │                                                         │
│    ├─── Inactivity timeout (30 min default)                 │
│    │         │                                               │
│    │         └── Session terminated                         │
│    │                                                         │
│    ├─── User logout                                          │
│    │         │                                               │
│    │         └── Tokens revoked immediately                 │
│    │                                                         │
│    └─── Admin revocation                                     │
│              │                                               │
│              └── All user sessions terminated               │
│                                                              │
│  Session End                                                 │
│    │  - Tokens invalidated                                   │
│    │  - Memory cleared                                       │
│    │  - Audit event logged                                   │
└─────────────────────────────────────────────────────────────┘
```

### Concurrent Sessions

| Setting | Default | Description |
|---------|---------|-------------|
| Max sessions | 5 | Per user limit |
| Session visibility | Yes | Users can view active sessions |
| Remote logout | Yes | Terminate other sessions |

---

## Sharing & Delegation

### Vault Sharing

| Share Type | Description | Permissions |
|------------|-------------|-------------|
| **Item share** | Single item | Read, Read/Write |
| **Collection share** | Group of items | Configurable |
| **Organization share** | All members | Role-based |

### Sharing Permissions

```
┌─────────────────────────────────────────────────────────────┐
│                 SHARE PERMISSIONS                            │
│                                                              │
│  Owner (Creator)                                             │
│    │                                                         │
│    ├── Can grant: Read, Read/Write, Manage                  │
│    ├── Can revoke: Any permission                           │
│    └── Can delete: Original item                            │
│                                                              │
│  Shared User                                                 │
│    │                                                         │
│    ├── Read: View only, copy to clipboard                   │
│    ├── Read/Write: View, edit, but not delete              │
│    └── Manage: Full control except ownership transfer       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Emergency Access

| Feature | Description |
|---------|-------------|
| Trusted contacts | Designated recovery users |
| Wait period | Configurable (1-30 days) |
| Notification | Owner notified of request |
| Revocation | Owner can reject during wait |

---

## Audit Trail

### Logged Events

| Category | Events |
|----------|--------|
| **Authentication** | Login, logout, MFA, failed attempts |
| **Authorization** | Access granted, denied |
| **Data access** | View, create, edit, delete items |
| **Sharing** | Share, revoke, accept |
| **Admin actions** | User management, settings changes |
| **Security** | Password change, MFA enable/disable |

### Audit Log Fields

| Field | Description |
|-------|-------------|
| `timestamp` | Event time (UTC) |
| `user_id` | Acting user |
| `action` | Event type |
| `resource` | Affected resource |
| `ip_address` | Source IP |
| `user_agent` | Browser/client |
| `result` | Success/failure |
| `details` | Additional context |

### Log Protection

- Cryptographic chaining (tamper detection)
- Digital signatures
- Immutable storage
- 3-year retention

---

## Best Practices

### For Users

1. Use strong, unique master password
2. Enable MFA (preferably FIDO2)
3. Review active sessions regularly
4. Report suspicious activity

### For Administrators

1. Enforce MFA for all users
2. Implement least privilege
3. Regular access reviews
4. Monitor audit logs
5. Configure conditional access

### For Organizations

1. Define clear access policies
2. Use role-based access control
3. Segment sensitive data
4. Regular security training
5. Incident response planning

---

## Related Documents

- [Security Architecture](ARCHITECTURE.md)
- [Encryption](ENCRYPTION.md)
- [Compliance Overview](../compliance/OVERVIEW.md)
