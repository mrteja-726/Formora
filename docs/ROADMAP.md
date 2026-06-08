# Formora — Product Roadmap

**Version:** 1.0.0  
**Status:** Draft  
**Last Updated:** 2026-06-06

---

## Vision

> **"Fill any form, anywhere, in one click."**
>
> Formora will become the universal identity layer for the internet — a secure, AI-powered vault that makes every form feel like it was already filled out.

---

## Guiding Principles

1. **Privacy by design** — users own their data, always
2. **Accuracy over speed** — never autofill if not confident
3. **Universal compatibility** — work everywhere users work
4. **Incremental trust** — earn user trust feature by feature

---

## Timeline Overview

```
Q3 2026   ─── Phase 1: Foundation
Q4 2026   ─── Phase 2: Extension & Desktop
Q1 2027   ─── Phase 3: Growth & Monetisation
Q2 2027   ─── Phase 4: Enterprise & Scale
```

---

## Phase 1 — Foundation (Q3 2026)

**Goal:** Core infrastructure, working autofill loop, private beta with 500 users.

### Milestones

| # | Feature | Target Date | Status |
|---|---------|-------------|--------|
| 1.1 | Authentication System | Week 2 | 🔲 Planned |
| 1.2 | User Profile (CRUD) | Week 3 | 🔲 Planned |
| 1.3 | Document Upload Engine | Week 4 | 🔲 Planned |
| 1.4 | OCR Engine (Google Vision) | Week 5 | 🔲 Planned |
| 1.5 | AI Mapping Engine (LLM) | Week 7 | 🔲 Planned |
| 1.6 | Autofill Engine (DOM injection) | Week 8 | 🔲 Planned |
| 1.7 | Chrome Extension MVP | Week 10 | 🔲 Planned |
| 1.8 | Mobile App (Flutter) — Profile + Vault | Week 12 | 🔲 Planned |

### Exit Criteria
- [ ] End-to-end autofill works on ≥ 20 popular sites
- [ ] OCR accuracy ≥ 95 % on passport and driver's license
- [ ] 500 private beta users with ≥ 60 % weekly retention

---

## Phase 2 — Extension & Desktop (Q4 2026)

**Goal:** Multi-browser support, desktop app, public launch.

| # | Feature | Notes |
|---|---------|-------|
| 2.1 | Firefox & Edge Extension | Port Chrome extension |
| 2.2 | Safari Extension (macOS) | Web Extensions API |
| 2.3 | Desktop App — Windows | Flutter desktop + accessibility APIs |
| 2.4 | Desktop App — macOS | Accessibility API (AXUIElement) |
| 2.5 | Field-by-field Confirmation Mode | User approves each fill |
| 2.6 | Site Trust Controls | Allowlist / blocklist |
| 2.7 | Public Launch & Waitlist | Product Hunt campaign |
| 2.8 | Payments (Stripe) — Pro Plan | $9.99/month |

### Exit Criteria
- [ ] 5,000 MAU post-launch
- [ ] Chrome Web Store rating ≥ 4.5 ★
- [ ] $10k MRR

---

## Phase 3 — Growth & Monetisation (Q1 2027)

| # | Feature | Notes |
|---|---------|-------|
| 3.1 | Profile Import (LinkedIn, résumé PDF) | Reduce onboarding friction |
| 3.2 | Shared Profiles (Teams) | Up to 5 members on Business plan |
| 3.3 | API Access | RESTful API for enterprise integrations |
| 3.4 | Audit Logs UI | Exportable CSV/PDF |
| 3.5 | GDPR Data Export | One-click JSON download |
| 3.6 | Mobile Autofill (iOS QuickType / Android Autofill) | OS-level integration |
| 3.7 | Referral Program | Viral growth loop |

### Exit Criteria
- [ ] 25,000 MAU
- [ ] $50k MRR
- [ ] NPS ≥ 50

---

## Phase 4 — Enterprise & Scale (Q2 2027)

| # | Feature | Notes |
|---|---------|-------|
| 4.1 | SSO (SAML 2.0 / OIDC) | Enterprise requirement |
| 4.2 | White-label SDK | OEM for HR / healthcare platforms |
| 4.3 | SOC 2 Type II Audit | Enterprise trust signal |
| 4.4 | HIPAA Business Associate Agreement | Medical market |
| 4.5 | Multi-region Deployment | EU data residency |
| 4.6 | Offline Mode | PWA + local encryption |
| 4.7 | AI-Generated Form Templates | Reverse: generate forms from profile |

### Exit Criteria
- [ ] 3 enterprise customers (≥ $5k/month ARR each)
- [ ] $100k MRR
- [ ] SOC 2 Type II certification received

---

## Parking Lot (Future Consideration)

- Biometric authentication (Face ID / fingerprint on mobile)
- Smart contract identity (Web3 / decentralised identity)
- Browser AI assistant (highlight and explain unfamiliar form fields)
- Voice-driven profile updates

---

## Dependencies & Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| LLM API cost overrun | Medium | High | Cache embeddings, fall back to rules-based mapping |
| Browser extension policy changes | Low | High | Build Web Extensions compliant; maintain MV3 |
| GDPR enforcement action | Low | Critical | Privacy-by-design, DPA appointment in EU |
| OCR accuracy below target | Medium | Medium | Multi-provider fallback + human correction UI |
| Slow user adoption | Medium | High | Onboarding investment, referral program |

---

*End of ROADMAP.md v1.0*
