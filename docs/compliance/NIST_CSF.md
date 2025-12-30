# NIST Cybersecurity Framework Compliance

**Document Version**: 1.0
**Last Updated**: 2025-12-30
**Framework**: NIST Cybersecurity Framework 2.0

---

## Overview

This document maps Forlock's security controls to the NIST Cybersecurity Framework (CSF) core functions.

**Overall Maturity**: Tier 2-3 (Risk Informed to Repeatable)
**Compliance Score**: 85%

---

## Framework Summary

| Function | Category Count | Compliance | Tier |
|----------|---------------|------------|------|
| **IDENTIFY** | 6 | 80% | Tier 2 |
| **PROTECT** | 6 | 95% | Tier 3 |
| **DETECT** | 3 | 85% | Tier 2-3 |
| **RESPOND** | 5 | 85% | Tier 3 |
| **RECOVER** | 3 | 90% | Tier 3 |

---

## IDENTIFY (ID)

### ID.AM - Asset Management

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| ID.AM-1: Physical devices inventoried | ✅ | Docker container inventory |
| ID.AM-2: Software platforms inventoried | ✅ | Dependency manifest (packages.json, .csproj) |
| ID.AM-3: Data flows mapped | ✅ | Architecture documentation |
| ID.AM-5: Resources prioritized | ✅ | Critical service classification |

### ID.BE - Business Environment

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| ID.BE-1: Organization's role identified | ✅ | Password/secrets management |
| ID.BE-2: Critical infrastructure identified | ✅ | Core services documented |
| ID.BE-5: Dependencies identified | ✅ | Service dependency map |

### ID.GV - Governance

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| ID.GV-1: Security policy established | ✅ | Documented policies |
| ID.GV-2: Roles and responsibilities | ✅ | RBAC, incident response team |
| ID.GV-3: Legal requirements identified | ✅ | GDPR/KVKK compliance |

### ID.RA - Risk Assessment

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| ID.RA-1: Asset vulnerabilities identified | ✅ | Dependency scanning |
| ID.RA-2: Threat intelligence | ⚠️ | Path scanning (limited external feeds) |
| ID.RA-5: Threats and risks assessed | ✅ | Risk-based authentication |

### ID.RM - Risk Management Strategy

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| ID.RM-1: Risk management processes | ✅ | Security roadmap |
| ID.RM-2: Risk tolerance defined | ✅ | RTO/RPO objectives |

---

## PROTECT (PR)

### PR.AC - Identity Management & Access Control

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| PR.AC-1: Identities managed | ✅ | Local + LDAP + OIDC |
| PR.AC-2: Physical access managed | ✅ | Cloud provider controls |
| PR.AC-3: Remote access managed | ✅ | TLS, authentication required |
| PR.AC-4: Access permissions managed | ✅ | RBAC + PBAC |
| PR.AC-5: Network integrity protected | ✅ | Docker isolation, firewall |
| PR.AC-6: Identities proofed | ✅ | Email verification, MFA |

### PR.AT - Awareness and Training

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| PR.AT-1: Users informed | ✅ | Security notifications |
| PR.AT-2: Privileged users trained | ✅ | Admin training |

### PR.DS - Data Security

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| PR.DS-1: Data-at-rest protected | ✅ | AES-256-GCM encryption |
| PR.DS-2: Data-in-transit protected | ✅ | TLS 1.3 |
| PR.DS-3: Asset lifecycle managed | ✅ | Vault item lifecycle |
| PR.DS-4: Availability ensured | ✅ | Redundancy, backups |
| PR.DS-5: Data leakage prevented | ✅ | DLP controls, export monitoring |

### PR.IP - Information Protection

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| PR.IP-1: Security baseline | ✅ | Infrastructure as Code |
| PR.IP-3: Configuration change control | ✅ | Git-based versioning |
| PR.IP-4: Backups conducted | ✅ | Daily + continuous |
| PR.IP-9: Response plans tested | ✅ | Quarterly DR drills |
| PR.IP-10: Protection processes improved | ✅ | Quarterly reviews |

### PR.MA - Maintenance

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| PR.MA-1: Maintenance performed | ✅ | Regular patching |
| PR.MA-2: Remote maintenance controlled | ✅ | SSH key auth, audit logging |

### PR.PT - Protective Technology

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| PR.PT-1: Audit logs protected | ✅ | Cryptographic chaining |
| PR.PT-2: Removable media protected | ✅ | No removable media |
| PR.PT-3: Least functionality | ✅ | Minimal container images |
| PR.PT-4: Communications protected | ✅ | TLS, network segmentation |

---

## DETECT (DE)

### DE.AE - Anomalies and Events

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| DE.AE-1: Network baseline established | ✅ | Traffic monitoring |
| DE.AE-2: Events analyzed | ✅ | Graylog SIEM |
| DE.AE-3: Event data correlated | ✅ | Attack tracking (AttackTrackId) |
| DE.AE-4: Impact determined | ✅ | Severity classification |

### DE.CM - Continuous Monitoring

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| DE.CM-1: Network monitored | ✅ | Graylog, access logs |
| DE.CM-2: Physical environment monitored | ⚠️ | Cloud provider dependent |
| DE.CM-3: Personnel activity monitored | ✅ | Audit logging |
| DE.CM-4: Malicious code detected | ✅ | Container scanning |
| DE.CM-6: External service activity monitored | ✅ | API logging |
| DE.CM-7: Unauthorized entities monitored | ✅ | Path scanning detection |
| DE.CM-8: Vulnerability scans performed | ✅ | Dependency scanning |

### DE.DP - Detection Processes

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| DE.DP-1: Roles defined | ✅ | Incident response team |
| DE.DP-2: Activities comply with requirements | ✅ | GDPR compliance |
| DE.DP-4: Event information communicated | ✅ | Alerting, dashboard |
| DE.DP-5: Detection processes improved | ✅ | Quarterly reviews |

---

## RESPOND (RS)

### RS.RP - Response Planning

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RS.RP-1: Response plan executed | ✅ | [Incident Response Playbook](../operations/INCIDENT_RESPONSE.md) |

### RS.CO - Communications

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RS.CO-1: Personnel know roles | ✅ | IRT defined |
| RS.CO-2: Events reported | ✅ | Escalation procedures |
| RS.CO-3: Information shared | ✅ | Internal communication |
| RS.CO-4: Coordination with stakeholders | ✅ | Customer notification templates |

### RS.AN - Analysis

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RS.AN-1: Notifications investigated | ✅ | Triage procedures |
| RS.AN-2: Impact understood | ✅ | Severity classification |
| RS.AN-3: Forensics performed | ✅ | Evidence preservation |
| RS.AN-4: Incidents categorized | ✅ | Incident types defined |

### RS.MI - Mitigation

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RS.MI-1: Incidents contained | ✅ | Containment playbooks |
| RS.MI-2: Incidents mitigated | ✅ | Eradication procedures |
| RS.MI-3: Vulnerabilities mitigated | ✅ | Patch management |

### RS.IM - Improvements

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RS.IM-1: Response plans incorporate lessons | ✅ | Post-incident reviews |
| RS.IM-2: Response strategies updated | ✅ | Playbook updates |

---

## RECOVER (RC)

### RC.RP - Recovery Planning

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RC.RP-1: Recovery plan executed | ✅ | [Disaster Recovery Plan](../operations/DISASTER_RECOVERY.md) |

### RC.IM - Improvements

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RC.IM-1: Recovery plans incorporate lessons | ✅ | Post-incident updates |
| RC.IM-2: Recovery strategies updated | ✅ | Quarterly DR reviews |

### RC.CO - Communications

| Subcategory | Status | Implementation |
|-------------|--------|----------------|
| RC.CO-1: Public relations managed | ✅ | Communication templates |
| RC.CO-2: Reputation repaired | ✅ | Transparency procedures |
| RC.CO-3: Recovery communicated | ✅ | Status page support |

---

## Maturity Roadmap

### Current State → Target State

| Function | Current | Target | Gap |
|----------|---------|--------|-----|
| IDENTIFY | Tier 2 | Tier 3 | Threat intelligence integration |
| PROTECT | Tier 3 | Tier 3 | ✓ Achieved |
| DETECT | Tier 2-3 | Tier 3 | ML anomaly detection |
| RESPOND | Tier 3 | Tier 3 | ✓ Achieved |
| RECOVER | Tier 3 | Tier 3 | ✓ Achieved |

### Improvement Initiatives

| Initiative | Function | Timeline | Priority |
|------------|----------|----------|----------|
| External threat feeds | IDENTIFY | Q1 2026 | High |
| ML anomaly detection | DETECT | Q2 2026 | Medium |
| File integrity monitoring | DETECT | Q1 2026 | High |
| Automated response | RESPOND | Q3 2026 | Medium |

---

## Framework Tiers Explained

| Tier | Name | Description |
|------|------|-------------|
| **Tier 1** | Partial | Ad hoc, reactive |
| **Tier 2** | Risk Informed | Risk-aware but not org-wide |
| **Tier 3** | Repeatable | Consistent, documented processes |
| **Tier 4** | Adaptive | Continuous improvement, predictive |

---

## Related Documents

- [Compliance Overview](OVERVIEW.md)
- [ISO 27001 Controls](ISO_27001.md)
- [Security Architecture](../security/ARCHITECTURE.md)
