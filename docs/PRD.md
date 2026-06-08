# Formora — Product Requirements Document (PRD)

**Version:** 1.0.0  
**Status:** Draft  
**Last Updated:** 2026-06-06  
**Owner:** Formora Core Team

---

## 1. Executive Summary

Formora is an AI-powered form automation platform that eliminates the repetitive burden of filling out digital forms. By combining Optical Character Recognition (OCR), large language models, and a universal browser extension, Formora learns a user's profile once and automatically populates any form—whether on the web, a desktop application, or a mobile device—with the correct data.

---

## 2. Problem Statement

Users fill out the same information hundreds of times per year across job applications, medical intakes, government portals, and e-commerce checkouts. This is:

- **Time-consuming** — average of 4–8 minutes per complex form
- **Error-prone** — manual re-entry introduces typos and inconsistencies
- **Frustrating** — users abandon forms at a 67 % rate when they are too long (Baymard Institute, 2024)

---

## 3. Goals & Success Metrics

| Goal | KPI | Target (12 months) |
|------|-----|--------------------|
| Reduce form-fill time | Avg. time saved per session | ≥ 3 minutes |
| High autofill accuracy | Field-match accuracy | ≥ 95 % |
| User adoption | Monthly Active Users | 50,000 |
| Retention | 30-day retention | ≥ 60 % |
| Revenue | Monthly Recurring Revenue | $100k |

---

## 4. User Personas

### 4.1 The Job Seeker — "Alex"
- Age 25–35, applies to 10–30 jobs per month
- Pain: Repeating the same resume fields on every portal
- Need: One-click autofill for job application forms

### 4.2 The Medical Patient — "Maria"
- Age 40–65, visits multiple specialists per year
- Pain: Filling the same health history at every clinic
- Need: Secure, HIPAA-aware profile that pre-fills intake forms

### 4.3 The Power User / Developer — "Sam"
- Age 20–40, uses many SaaS tools
- Pain: Repetitive onboarding forms for every new service
- Need: Programmable profiles and API access

---

## 5. Feature Requirements

### Phase 1 — Foundation (Months 1–3)

#### 5.1 Authentication System
- Email/password registration with email verification
- OAuth2 social login (Google, Apple)
- Multi-factor authentication (TOTP)
- Session management with JWT + refresh tokens
- Password reset flow

**Acceptance Criteria:**
- [ ] User can register, verify email, and log in within 2 minutes
- [ ] MFA setup completes in under 60 seconds
- [ ] Tokens expire after 15 min; refresh tokens valid for 30 days

#### 5.2 User Profile
- Structured profile with sections: Personal, Contact, Employment, Education, Medical (optional)
- Document vault for ID scans, certificates, and resume
- Profile completeness score
- Privacy controls per field (public / private / masked)

**Acceptance Criteria:**
- [ ] Profile CRUD operations respond in < 200 ms (p95)
- [ ] All sensitive fields encrypted at rest (AES-256)
- [ ] User can export profile as JSON or PDF

#### 5.3 Document Upload Engine
- Support for PDF, JPEG, PNG, TIFF, DOCX
- Max upload size: 25 MB per file, 1 GB total per user
- Virus scanning before storage (ClamAV)
- Thumbnail generation for previews

**Acceptance Criteria:**
- [ ] Upload completes in < 5 s for a 5 MB PDF on broadband
- [ ] Infected files rejected with user-friendly error

#### 5.4 OCR Engine
- Integration with Google Vision API (primary) + Tesseract (fallback)
- Structured field extraction from ID documents (passport, driver's license)
- Confidence scoring per extracted field
- Manual correction UI

**Acceptance Criteria:**
- [ ] ≥ 95 % field extraction accuracy on standard IDs
- [ ] OCR results returned in < 3 s for single-page documents

#### 5.5 AI Mapping Engine
- Maps profile fields to detected form fields using semantic matching
- LLM-backed context understanding (e.g., "First Name" ↔ "Given Name")
- Custom mapping rules per domain/website
- Conflict resolution when multiple profile fields match

**Acceptance Criteria:**
- [ ] ≥ 92 % correct field mapping on benchmark form set
- [ ] Mapping inference < 500 ms (cached) / < 2 s (cold)

#### 5.6 Autofill Engine
- DOM injection for browser forms
- Native accessibility API integration for desktop apps
- Keyboard simulation fallback
- Undo autofill action

**Acceptance Criteria:**
- [ ] Autofill completes within 1 s of trigger
- [ ] No detectable automation signatures in browser fingerprint tests

### Phase 2 — Extension & Desktop (Months 4–6)

#### 5.7 Browser Extension
- Chrome, Firefox, Edge, Safari (via Web Extensions API)
- Inline autofill suggestions (à la password manager UX)
- One-click fill, field-by-field confirmation mode
- Site trust controls

#### 5.8 Desktop Integration
- Windows and macOS system tray app
- Intercepts form focus via accessibility APIs
- Works with Electron apps, native forms, PDF editors

### Phase 3 — Growth & Monetization (Months 7–12)

- Team workspaces and shared profiles
- API access for enterprise integrations
- Audit logs and compliance exports
- White-label SDK

---

## 6. Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| Performance | API p95 latency < 200 ms |
| Availability | 99.9 % uptime SLA |
| Security | OWASP Top 10 compliance, SOC 2 Type II roadmap |
| Scalability | Horizontal scaling to 1M users without re-architecture |
| Accessibility | WCAG 2.1 AA |
| Compliance | GDPR, CCPA, HIPAA (optional medical module) |

---

## 7. Out of Scope (v1.0)

- AI-powered form generation
- Biometric authentication (Face ID on mobile planned for v2)
- Offline-first mode

---

## 8. Dependencies

- Google Vision API — OCR
- OpenAI / Gemini API — AI mapping
- Stripe — payments
- SendGrid — transactional email
- AWS S3 / GCS — document storage

---

## 9. Open Questions

1. Which LLM provider is primary for the AI Mapping Engine?
2. Should the medical profile module require separate consent flow or integrate into the main profile?
3. What is the pricing model — freemium, subscription, or per-form?

---

*End of PRD v1.0*
