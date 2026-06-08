// ============================================================
// Formora Extension — Shared Types
// ============================================================

export interface FormField {
  selector: string;
  label: string;
  type: string;
  placeholder?: string;
  name?: string;
  element?: HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement;
}

export interface FieldMapping {
  selector: string;
  profileFieldKey: string | null;
  confidence: number;
  source: 'rule' | 'llm' | 'cache';
  requiresConfirmation: boolean;
}

export interface AnalyzeResponse {
  success: boolean;
  data: {
    sessionId: string;
    mappings: FieldMapping[];
  };
}

export interface FillResponse {
  success: boolean;
  data: {
    sessionId: string;
    filledCount: number;
    values: Record<string, string | null>;
  };
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number; // Unix ms
}

export interface TrustConfig {
  [domain: string]: 'trusted' | 'blocked' | 'ask';
}

// ── Extension message types ────────────────────────────────

export type ExtMessage =
  | { type: 'FORM_DETECTED'; fields: FormField[]; domain: string }
  | { type: 'TRIGGER_FILL'; sessionId: string; selectors: string[] }
  | { type: 'FILL_VALUES'; values: Record<string, string | null> }
  | { type: 'AUTH_STATUS'; isLoggedIn: boolean }
  | { type: 'GET_AUTH_STATUS' }
  | { type: 'GET_FIELDS' }
  | { type: 'OPEN_POPUP' }
  | { type: 'SITE_TRUST'; domain: string; action: 'trusted' | 'blocked' | 'ask' };
