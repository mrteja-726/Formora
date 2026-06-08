# Formora — System Architecture

**Version:** 1.0.0  
**Status:** Draft  
**Last Updated:** 2026-06-06

---

## 1. Architecture Overview

Formora follows a **modular monorepo** structure with clearly separated concerns across four deployment targets: mobile app, desktop app, browser extension, and cloud backend.

```
┌─────────────────────────────────────────────────────────────────┐
│                          Clients                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Mobile App  │  │ Desktop App  │  │  Browser Extension   │  │
│  │  (Flutter)   │  │  (Flutter)   │  │  (Web Extensions API)│  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
└─────────┼─────────────────┼───────────────────── ┼─────────────┘
          │                 │                       │
          └─────────────────┴───────────────────────┘
                                    │ HTTPS / WSS
                     ┌──────────────▼───────────────┐
                     │     API Gateway / BFF         │
                     │  (NestJS — apps/api)          │
                     └──────────────┬───────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
┌────────▼────────┐      ┌──────────▼──────────┐   ┌──────────▼──────────┐
│  Auth Service   │      │   Profile Service   │   │  Document Service   │
│  (JWT / OAuth2) │      │  (CRUD + Encryption)│   │  (Upload + OCR)     │
└────────┬────────┘      └──────────┬──────────┘   └──────────┬──────────┘
         │                          │                          │
         └──────────────────────────┼──────────────────────────┘
                                    │
                     ┌──────────────▼───────────────┐
                     │      AI / ML Services        │
                     │  - OCR (Google Vision)       │
                     │  - Mapping (LLM API)         │
                     │  - Autofill Inference        │
                     └──────────────┬───────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
┌────────▼────────┐      ┌──────────▼──────────┐   ┌──────────▼──────────┐
│   PostgreSQL    │      │      Redis Cache     │   │  Object Storage     │
│   (Primary DB)  │      │  (Sessions, Queues) │   │  (S3 / GCS)         │
└─────────────────┘      └─────────────────────┘   └─────────────────────┘
```

---

## 2. Repository Structure

```
formora/                        ← Monorepo root
├── apps/
│   ├── mobile/                 ← Flutter mobile (iOS + Android)
│   ├── desktop/                ← Flutter desktop (Windows + macOS)
│   └── extension/              ← Browser extension (JS/TS + WXT)
├── backend/
│   └── api/                    ← NestJS REST + WebSocket API
├── docs/                       ← All project documentation
│   ├── prd/                    ← Product requirements
│   ├── architecture/           ← Architecture decision records (ADRs)
│   └── database/               ← Schema diagrams and migration notes
├── docker/                     ← Dockerfiles and compose configs
├── .github/
│   └── workflows/              ← GitHub Actions CI/CD
└── scripts/                    ← Dev/ops utility scripts
```

---

## 3. Technology Stack

### 3.1 Frontend / Clients

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Mobile | Flutter 3.x (Dart) | Single codebase for iOS + Android |
| Desktop | Flutter 3.x (Dart) | Single codebase for Win + macOS |
| Extension | TypeScript + WXT | Web Extensions Manifest V3 |
| State Management | Riverpod (Flutter) / Zustand (JS) | Scalable, testable |
| HTTP Client | Dio (Flutter) / Axios (JS) | Interceptors, retry logic |

### 3.2 Backend

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Framework | NestJS (Node.js + TypeScript) | Modular, DI, decorators |
| ORM | Prisma | Type-safe, migration tooling |
| Auth | Passport.js + JWT | Flexible strategy pattern |
| Queue | BullMQ (Redis) | Reliable job processing |
| WebSocket | Socket.IO | Real-time autofill events |
| Validation | class-validator + Zod | Schema enforcement at boundary |

### 3.3 Infrastructure

| Component | Technology |
|-----------|-----------|
| Container | Docker + Docker Compose |
| CI/CD | GitHub Actions |
| Database | PostgreSQL 16 |
| Cache/Queue | Redis 7 |
| Object Storage | AWS S3 (prod) / MinIO (local) |
| Reverse Proxy | Nginx |
| Secrets | AWS Secrets Manager / Doppler |

### 3.4 AI / ML Services

| Purpose | Service |
|---------|---------|
| OCR | Google Vision API (primary), Tesseract (fallback) |
| AI Mapping | OpenAI GPT-4o / Google Gemini 1.5 Pro |
| Embeddings | text-embedding-3-small |

---

## 4. API Design Principles

- **RESTful** for CRUD operations (versioned at `/api/v1/`)
- **WebSocket** for real-time autofill coordination
- **JWT** access tokens (15 min) + **refresh tokens** (30 days, rotating)
- **Rate limiting** via Redis sliding window (100 req/min per IP, 1000/min per user)
- **Pagination** with cursor-based pagination for all list endpoints
- All responses follow the envelope pattern:

```json
{
  "success": true,
  "data": { ... },
  "meta": { "requestId": "...", "timestamp": "..." }
}
```

---

## 5. Security Architecture

See [SECURITY.md](./SECURITY.md) for the full threat model and controls.

Key principles:
- **Zero-trust network**: All internal service calls authenticated
- **Encryption at rest**: AES-256 for sensitive profile fields
- **Encryption in transit**: TLS 1.3 enforced
- **Least privilege**: RBAC with fine-grained scopes
- **Audit trail**: Immutable logs for all data access events

---

## 6. Scalability Plan

| Milestone | Strategy |
|-----------|----------|
| 0–10k users | Single-region Docker Compose on VPS |
| 10k–100k users | Kubernetes (EKS/GKE), read replicas |
| 100k+ users | Multi-region, CDN, global DB replication |

---

## 7. Architecture Decision Records (ADRs)

| ID | Decision | Status |
|----|----------|--------|
| ADR-001 | Use Flutter for all client apps | Accepted |
| ADR-002 | NestJS over Express for backend | Accepted |
| ADR-003 | Prisma over TypeORM | Accepted |
| ADR-004 | PostgreSQL as primary datastore | Accepted |
| ADR-005 | Monorepo with per-app Git branches | Accepted |

---

*End of ARCHITECTURE.md v1.0*
