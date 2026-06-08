# Formora — API Specification

**Version:** 1.0.0  
**Status:** Draft  
**Last Updated:** 2026-06-06  
**Base URL:** `https://api.formora.app/api/v1`

---

## 1. Conventions

### 1.1 Authentication
All endpoints (unless marked **Public**) require:
```
Authorization: Bearer <access_token>
```

### 1.2 Response Envelope
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "requestId": "req_01hwjkz...",
    "timestamp": "2026-06-06T12:00:00.000Z"
  }
}
```

### 1.3 Error Response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "email must be a valid email address",
    "details": [ { "field": "email", "message": "..." } ]
  },
  "meta": { ... }
}
```

### 1.4 HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | OK |
| 201 | Created |
| 204 | No Content (delete) |
| 400 | Bad Request / Validation Error |
| 401 | Unauthenticated |
| 403 | Forbidden |
| 404 | Not Found |
| 409 | Conflict (e.g. email already exists) |
| 422 | Unprocessable Entity |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

---

## 2. Authentication Endpoints

### 2.1 Register
**POST** `/auth/register` — **Public**

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecureP@ss1!",
  "fullName": "Jane Doe"
}
```

**Response `201`:**
```json
{
  "success": true,
  "data": {
    "userId": "uuid",
    "email": "user@example.com",
    "message": "Verification email sent"
  }
}
```

---

### 2.2 Verify Email
**POST** `/auth/verify-email` — **Public**

**Request:**
```json
{ "token": "eyJ..." }
```

---

### 2.3 Login
**POST** `/auth/login` — **Public**

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecureP@ss1!"
}
```

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJ...",
    "refreshToken": "eyJ...",
    "expiresIn": 900,
    "requiresMfa": false
  }
}
```

---

### 2.4 Refresh Token
**POST** `/auth/refresh` — **Public**

**Request:**
```json
{ "refreshToken": "eyJ..." }
```

---

### 2.5 Logout
**POST** `/auth/logout`

Revokes the current refresh token.

---

### 2.6 OAuth2 Initiate
**GET** `/auth/oauth/:provider` — **Public**

`provider`: `google` | `apple`

Redirects to provider's authorization URL.

---

### 2.7 OAuth2 Callback
**GET** `/auth/oauth/:provider/callback` — **Public**

---

### 2.8 MFA Setup
**POST** `/auth/mfa/setup`

Returns TOTP provisioning URI and QR code.

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "secret": "BASE32...",
    "qrCodeUrl": "data:image/png;base64,..."
  }
}
```

---

### 2.9 MFA Verify
**POST** `/auth/mfa/verify`

```json
{ "code": "123456" }
```

---

### 2.10 Password Reset Request
**POST** `/auth/forgot-password` — **Public**

```json
{ "email": "user@example.com" }
```

---

### 2.11 Password Reset Confirm
**POST** `/auth/reset-password` — **Public**

```json
{ "token": "...", "newPassword": "NewP@ss1!" }
```

---

## 3. User Endpoints

### 3.1 Get Current User
**GET** `/users/me`

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "fullName": "Jane Doe",
    "avatarUrl": null,
    "plan": "free",
    "storageUsedBytes": 0,
    "storageLimitBytes": 1073741824,
    "emailVerifiedAt": "2026-06-06T..."
  }
}
```

---

### 3.2 Update Current User
**PATCH** `/users/me`

```json
{
  "fullName": "Jane Smith",
  "avatarUrl": "https://..."
}
```

---

### 3.3 Delete Account
**DELETE** `/users/me`

Initiates a 30-day soft-delete grace period.

---

## 4. Profile Endpoints

### 4.1 Get Profile
**GET** `/profile`

Returns all non-encrypted field metadata (not values).

---

### 4.2 Get Profile Field (Decrypted)
**GET** `/profile/fields/:fieldKey`

Returns the decrypted value for a single field. Each access is logged in `audit_logs`.

---

### 4.3 Upsert Profile Field
**PUT** `/profile/fields/:fieldKey`

```json
{
  "section": "personal",
  "value": "Jane",
  "dataType": "string",
  "visibility": "private"
}
```

---

### 4.4 Delete Profile Field
**DELETE** `/profile/fields/:fieldKey`

---

### 4.5 Get Profile Completeness
**GET** `/profile/completeness`

```json
{ "success": true, "data": { "score": 72, "missingSections": ["medical"] } }
```

---

## 5. Document Endpoints

### 5.1 Upload Document
**POST** `/documents` — `multipart/form-data`

| Field | Type | Required |
|-------|------|----------|
| `file` | binary | Yes |
| `documentType` | string | No |

**Response `201`:**
```json
{
  "success": true,
  "data": {
    "documentId": "uuid",
    "filename": "passport.pdf",
    "status": "processing"
  }
}
```

---

### 5.2 List Documents
**GET** `/documents?page=1&limit=20`

---

### 5.3 Get Document
**GET** `/documents/:id`

---

### 5.4 Get Document Download URL
**GET** `/documents/:id/download`

Returns a pre-signed URL valid for 15 minutes.

---

### 5.5 Delete Document
**DELETE** `/documents/:id`

---

### 5.6 Get OCR Results
**GET** `/documents/:id/ocr`

```json
{
  "success": true,
  "data": {
    "status": "completed",
    "overallConfidence": 97,
    "extractedFields": {
      "first_name": { "value": "Jane", "confidence": 99 },
      "last_name":  { "value": "Doe",  "confidence": 98 },
      "dob":        { "value": "1990-01-15", "confidence": 95 }
    }
  }
}
```

---

## 6. Autofill Endpoints

### 6.1 Analyze Form
**POST** `/autofill/analyze`

Sent by the extension when a form is detected.

```json
{
  "domain": "linkedin.com",
  "fields": [
    { "selector": "#first-name", "label": "First Name", "type": "text" },
    { "selector": "#last-name",  "label": "Last Name",  "type": "text" }
  ]
}
```

**Response `200`:**
```json
{
  "success": true,
  "data": {
    "sessionId": "uuid",
    "mappings": [
      {
        "selector": "#first-name",
        "profileFieldKey": "first_name",
        "confidence": 99,
        "requiresConfirmation": false
      }
    ]
  }
}
```

---

### 6.2 Execute Fill
**POST** `/autofill/sessions/:sessionId/fill`

```json
{ "confirmedMappings": ["#first-name", "#last-name"] }
```

Returns field values (decrypted, one-time) for the extension to inject.

---

### 6.3 Rate Fill Session
**POST** `/autofill/sessions/:sessionId/rate`

```json
{ "accuracy": 95, "feedback": "Phone field was wrong" }
```

---

## 7. Webhooks

Formora emits webhooks for async events (OCR complete, virus scan results):

```json
{
  "event": "document.ocr.completed",
  "data": { "documentId": "uuid", "status": "success" },
  "timestamp": "2026-06-06T..."
}
```

All webhooks are signed with `X-Formora-Signature: sha256=<HMAC>`.

---

*End of API_SPEC.md v1.0*
