# Formora — Database Design

**Version:** 1.0.0  
**Status:** Draft  
**Last Updated:** 2026-06-06  
**Engine:** PostgreSQL 16

---

## 1. Design Principles

- **UUID v7** primary keys (time-sortable, globally unique)
- **Soft deletes** via `deleted_at` timestamp — data is never hard-deleted
- **Audit columns** (`created_at`, `updated_at`, `deleted_at`) on every table
- **Encrypted columns** for PII fields (application-level AES-256, stored as `BYTEA`)
- **Row-level security** (PostgreSQL RLS) for multi-tenant isolation

---

## 2. Entity Relationship Overview

```
users
  │
  ├──< user_sessions       (active JWT/refresh token pairs)
  ├──< user_mfa_configs    (TOTP secrets)
  │
  └──< profiles            (one profile per user)
        │
        ├──< profile_fields      (key-value store for dynamic sections)
        ├──< profile_documents   (uploaded documents)
        │     └──< ocr_results   (extracted fields from documents)
        └──< autofill_mappings   (site-specific field mappings)

form_fill_sessions           (analytics: each autofill event)
audit_logs                   (immutable access/change records)
```

---

## 3. Table Definitions

### 3.1 `users`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK, DEFAULT gen_random_uuid() | User identifier |
| `email` | `VARCHAR(255)` | UNIQUE, NOT NULL | Login email |
| `email_verified_at` | `TIMESTAMPTZ` | NULLABLE | NULL until verified |
| `password_hash` | `VARCHAR(255)` | NULLABLE | bcrypt hash (NULL for OAuth-only users) |
| `full_name` | `VARCHAR(255)` | NOT NULL | Display name |
| `avatar_url` | `TEXT` | NULLABLE | Profile photo URL |
| `plan` | `VARCHAR(50)` | NOT NULL, DEFAULT 'free' | `free`, `pro`, `enterprise` |
| `storage_used_bytes` | `BIGINT` | NOT NULL, DEFAULT 0 | Running total of uploaded file bytes |
| `storage_limit_bytes` | `BIGINT` | NOT NULL, DEFAULT 1073741824 | 1 GB default |
| `is_active` | `BOOLEAN` | NOT NULL, DEFAULT TRUE | Account status |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |
| `deleted_at` | `TIMESTAMPTZ` | NULLABLE | Soft delete |

**Indexes:**
```sql
CREATE UNIQUE INDEX idx_users_email ON users (email) WHERE deleted_at IS NULL;
```

---

### 3.2 `user_oauth_providers`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `user_id` | `UUID` | FK → users.id | |
| `provider` | `VARCHAR(50)` | NOT NULL | `google`, `apple`, `github` |
| `provider_user_id` | `VARCHAR(255)` | NOT NULL | External user ID |
| `access_token_enc` | `BYTEA` | NULLABLE | Encrypted OAuth access token |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

**Indexes:**
```sql
CREATE UNIQUE INDEX idx_oauth_provider ON user_oauth_providers (provider, provider_user_id);
```

---

### 3.3 `user_sessions`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `user_id` | `UUID` | FK → users.id, ON DELETE CASCADE | |
| `refresh_token_hash` | `VARCHAR(255)` | UNIQUE, NOT NULL | SHA-256 of refresh token |
| `ip_address` | `INET` | NULLABLE | Client IP at creation |
| `user_agent` | `TEXT` | NULLABLE | Browser/device string |
| `expires_at` | `TIMESTAMPTZ` | NOT NULL | Refresh token expiry |
| `revoked_at` | `TIMESTAMPTZ` | NULLABLE | Token revocation time |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

---

### 3.4 `user_mfa_configs`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `user_id` | `UUID` | FK → users.id, UNIQUE | |
| `totp_secret_enc` | `BYTEA` | NOT NULL | Encrypted TOTP secret |
| `backup_codes_enc` | `BYTEA` | NOT NULL | Encrypted array of one-time codes |
| `enabled_at` | `TIMESTAMPTZ` | NULLABLE | NULL until user confirms setup |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

---

### 3.5 `profiles`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `user_id` | `UUID` | FK → users.id, UNIQUE | One profile per user |
| `completeness_score` | `SMALLINT` | NOT NULL, DEFAULT 0 | 0–100 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

---

### 3.6 `profile_fields`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `profile_id` | `UUID` | FK → profiles.id, ON DELETE CASCADE | |
| `section` | `VARCHAR(100)` | NOT NULL | `personal`, `contact`, `employment`, `education`, `medical` |
| `field_key` | `VARCHAR(100)` | NOT NULL | e.g. `first_name`, `dob` |
| `value_enc` | `BYTEA` | NOT NULL | AES-256 encrypted value |
| `data_type` | `VARCHAR(50)` | NOT NULL | `string`, `date`, `phone`, `email`, `number` |
| `visibility` | `VARCHAR(20)` | NOT NULL, DEFAULT 'private' | `public`, `private`, `masked` |
| `source` | `VARCHAR(50)` | NOT NULL, DEFAULT 'manual' | `manual`, `ocr`, `import` |
| `confidence` | `SMALLINT` | NULLABLE | OCR confidence 0–100 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

**Indexes:**
```sql
CREATE UNIQUE INDEX idx_profile_field ON profile_fields (profile_id, section, field_key);
```

---

### 3.7 `profile_documents`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `profile_id` | `UUID` | FK → profiles.id, ON DELETE CASCADE | |
| `filename` | `VARCHAR(255)` | NOT NULL | Original filename |
| `content_type` | `VARCHAR(100)` | NOT NULL | MIME type |
| `size_bytes` | `BIGINT` | NOT NULL | File size |
| `storage_key` | `TEXT` | NOT NULL | S3/GCS object key |
| `thumbnail_key` | `TEXT` | NULLABLE | Thumbnail object key |
| `document_type` | `VARCHAR(100)` | NULLABLE | `passport`, `drivers_license`, `resume`, etc. |
| `virus_scanned_at` | `TIMESTAMPTZ` | NULLABLE | ClamAV scan timestamp |
| `virus_clean` | `BOOLEAN` | NULLABLE | NULL until scanned |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |
| `deleted_at` | `TIMESTAMPTZ` | NULLABLE | Soft delete |

---

### 3.8 `ocr_results`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `document_id` | `UUID` | FK → profile_documents.id, ON DELETE CASCADE | |
| `provider` | `VARCHAR(50)` | NOT NULL | `google_vision`, `tesseract` |
| `raw_response` | `JSONB` | NOT NULL | Full provider response |
| `extracted_fields` | `JSONB` | NOT NULL | Structured key-value extraction |
| `overall_confidence` | `SMALLINT` | NOT NULL | Weighted average 0–100 |
| `processed_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

---

### 3.9 `autofill_mappings`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `user_id` | `UUID` | FK → users.id, ON DELETE CASCADE | |
| `domain` | `VARCHAR(255)` | NOT NULL | e.g. `linkedin.com` |
| `form_selector` | `TEXT` | NULLABLE | CSS selector for the form |
| `field_selector` | `TEXT` | NOT NULL | CSS selector for the field |
| `profile_field_key` | `VARCHAR(100)` | NOT NULL | Mapped profile field key |
| `ai_confidence` | `SMALLINT` | NOT NULL | Mapping confidence 0–100 |
| `user_confirmed` | `BOOLEAN` | NOT NULL, DEFAULT FALSE | Was the mapping confirmed by user? |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

---

### 3.10 `form_fill_sessions`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `user_id` | `UUID` | FK → users.id, ON DELETE SET NULL | |
| `domain` | `VARCHAR(255)` | NOT NULL | Site domain |
| `fields_detected` | `SMALLINT` | NOT NULL | Number of fields found on the form |
| `fields_filled` | `SMALLINT` | NOT NULL | Number of fields autofilled |
| `fill_accuracy` | `SMALLINT` | NULLABLE | User-rated accuracy 0–100 |
| `duration_ms` | `INTEGER` | NULLABLE | Time to complete autofill |
| `platform` | `VARCHAR(50)` | NOT NULL | `browser_extension`, `desktop`, `mobile` |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | |

---

### 3.11 `audit_logs`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `UUID` | PK | |
| `user_id` | `UUID` | NULLABLE | Acting user (NULL for system) |
| `action` | `VARCHAR(100)` | NOT NULL | e.g. `profile.field.read`, `document.delete` |
| `resource_type` | `VARCHAR(100)` | NOT NULL | Entity type |
| `resource_id` | `UUID` | NULLABLE | Entity ID |
| `metadata` | `JSONB` | NULLABLE | Additional context |
| `ip_address` | `INET` | NULLABLE | |
| `user_agent` | `TEXT` | NULLABLE | |
| `created_at` | `TIMESTAMPTZ` | NOT NULL, DEFAULT NOW() | **Never updated or deleted** |

---

## 4. Migration Strategy

- Managed by **Prisma Migrate** in development
- Production migrations are run via CI/CD pipeline with automated rollback on failure
- Destructive migrations (DROP COLUMN, etc.) require manual approval gate in GitHub Actions

---

## 5. Backup & Recovery

| Tier | Schedule | Retention | RTO | RPO |
|------|----------|-----------|-----|-----|
| Continuous WAL | Streaming | 7 days | 5 min | Near-zero |
| Daily snapshot | 02:00 UTC | 30 days | 1 hour | 24 hours |
| Weekly archive | Sunday | 1 year | 4 hours | 7 days |

---

*End of DATABASE.md v1.0*
