# Formora — Security Policy & Threat Model

**Version:** 1.0.0  
**Status:** Draft  
**Last Updated:** 2026-06-06  
**Compliance Targets:** OWASP Top 10, GDPR, CCPA, SOC 2 Type II (roadmap)

---

## 1. Security Philosophy

Formora handles highly sensitive personal data — government IDs, health records, financial details. Security is not a feature; it is a foundational requirement. We follow a **defence-in-depth** strategy with multiple independent layers of control.

---

## 2. Threat Model (STRIDE)

| Threat | Vector | Mitigation |
|--------|--------|-----------|
| **Spoofing** | Credential stuffing, OAuth phishing | Rate limiting, MFA, PKCE |
| **Tampering** | Man-in-the-middle, API parameter manipulation | TLS 1.3, signed JWTs, input validation |
| **Repudiation** | Disputed data access claims | Immutable audit logs |
| **Information Disclosure** | SQL injection, misconfigured S3, leaked tokens | Parameterised queries, bucket policies, token rotation |
| **Denial of Service** | Volumetric attacks, expensive queries | WAF, rate limiting, query timeouts |
| **Elevation of Privilege** | IDOR, JWT algorithm confusion | RBAC, resource ownership checks, `alg` whitelist |

---

## 3. Authentication & Authorization

### 3.1 Password Policy
- Minimum 12 characters
- Must contain uppercase, lowercase, digit, and special character
- Breached password check via HaveIBeenPwned API (k-anonymity model)
- bcrypt with cost factor 12

### 3.2 JWT Configuration
```
Access token:  15 minutes, RS256, audience: "formora-api"
Refresh token: 30 days, rotating (old token revoked on use)
Algorithm whitelist: ["RS256"] — rejects "none" and symmetric algorithms
```

### 3.3 MFA
- TOTP (RFC 6238) with 30-second window (±1 step tolerance)
- 10 single-use backup codes, stored as bcrypt hashes
- Recovery flow requires identity re-verification

### 3.4 OAuth2
- PKCE required for all flows
- State parameter validated to prevent CSRF
- Redirect URIs strictly whitelisted

### 3.5 Rate Limiting

| Endpoint | Limit |
|----------|-------|
| `POST /auth/login` | 10 req/min per IP |
| `POST /auth/register` | 5 req/min per IP |
| `POST /auth/forgot-password` | 3 req/min per IP |
| `GET /profile/fields/:key` | 60 req/min per user |
| All other endpoints | 1000 req/min per user / 100 req/min per IP |

---

## 4. Data Protection

### 4.1 Encryption at Rest

| Layer | Algorithm | Key Management |
|-------|-----------|---------------|
| Database fields (PII) | AES-256-GCM | AWS KMS / Doppler |
| Object storage files | AES-256-SSE | S3 managed keys |
| Backup snapshots | AES-256 | Separate KMS key |

Each encrypted field uses a unique IV (nonce). Envelope encryption: data key encrypted by master key.

### 4.2 Encryption in Transit
- TLS 1.3 enforced; TLS 1.0 and 1.1 disabled
- HSTS with `max-age=31536000; includeSubDomains; preload`
- Certificate pinning in mobile apps

### 4.3 Data Minimisation
- Only collect data explicitly needed for autofill
- Anonymous analytics (no PII in telemetry)
- Medical module requires separate opt-in consent

### 4.4 Data Retention
| Data Type | Retention |
|-----------|-----------|
| User account | Until deletion + 30-day grace |
| Autofill session logs | 90 days |
| Audit logs | 7 years |
| Support tickets | 3 years |

---

## 5. Infrastructure Security

### 5.1 Network
- All services run in private subnets; only API Gateway exposed to internet
- WAF rules: SQLi, XSS, SSRF, size limits
- DDoS protection via Cloudflare / AWS Shield

### 5.2 Container Security
- Base images: `node:20-alpine`, `dart:stable`
- No running as root inside containers
- Read-only root filesystems where possible
- Image scanning with Trivy in CI before every push

### 5.3 Secrets Management
- **No secrets in code or environment variable files committed to Git**
- Secrets fetched at runtime from AWS Secrets Manager or Doppler
- Secret rotation: API keys rotated every 90 days

### 5.4 Dependency Management
- `npm audit` and `dart pub audit` run in every CI pipeline
- Dependabot enabled for automated security PRs
- No unpinned dependency versions in production

---

## 6. Application Security

### 6.1 Input Validation
- All API inputs validated with `class-validator` (NestJS) + Zod schemas
- File uploads: MIME type checked server-side (not just extension)
- ClamAV antivirus scan before any file is stored or processed

### 6.2 SQL Injection Prevention
- Prisma ORM with parameterised queries — raw SQL forbidden except with explicit sign-off
- Database user has minimal privileges (no DDL rights in production)

### 6.3 CORS
```
Origin: https://formora.app, https://*.formora.app
Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Credentials: true
```

### 6.4 Security Headers (all responses)
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'; ...
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=()
```

### 6.5 IDOR Prevention
- Every resource query filters by `userId` — never accept a resource ID without ownership check
- Integration tests verify cross-user data isolation

---

## 7. Browser Extension Security

- Manifest V3 (no remote code execution)
- Content scripts communicate via `chrome.runtime.sendMessage` only
- No inline scripts (`eval`, `innerHTML` with user data)
- Minimum permission set: `activeTab`, `storage`, `identity`

---

## 8. Incident Response

| Severity | Definition | Response Time |
|----------|-----------|---------------|
| P0 — Critical | Data breach, service down | 15 minutes |
| P1 — High | Auth bypass, major data exposure | 1 hour |
| P2 — Medium | Elevated error rates, minor data leak | 4 hours |
| P3 — Low | Non-impacting anomaly | 24 hours |

**Breach notification:** GDPR requires 72-hour notification to supervisory authority; affected users notified within 7 days.

---

## 9. Responsible Disclosure

To report a security vulnerability, email **security@formora.app** with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment

We commit to acknowledging reports within 48 hours and resolving critical issues within 7 days.

---

*End of SECURITY.md v1.0*
