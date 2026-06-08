// ============================================================
// Formora Extension — API Client
// All calls to the Formora backend REST API
// ============================================================

import type { AuthTokens, AnalyzeResponse, FillResponse, FormField } from '../types';

const API_BASE = 'https://api.formora.app/api/v1';

// ── Token storage helpers ──────────────────────────────────

export async function getTokens(): Promise<AuthTokens | null> {
  const result = await chrome.storage.local.get('auth');
  return (result.auth as AuthTokens) ?? null;
}

export async function setTokens(tokens: AuthTokens): Promise<void> {
  await chrome.storage.local.set({ auth: tokens });
}

export async function clearTokens(): Promise<void> {
  await chrome.storage.local.remove('auth');
}

// ── HTTP helper with auto-refresh ──────────────────────────

async function request<T>(
  path: string,
  options: RequestInit = {},
  retry = true,
): Promise<T> {
  const tokens = await getTokens();

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  };

  if (tokens?.accessToken) {
    headers['Authorization'] = `Bearer ${tokens.accessToken}`;
  }

  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });

  // Token expired — refresh and retry once
  if (res.status === 401 && retry && tokens?.refreshToken) {
    const refreshed = await refreshAccessToken(tokens.refreshToken);
    if (refreshed) {
      return request<T>(path, options, false);
    } else {
      await clearTokens();
      throw new Error('Session expired. Please log in again.');
    }
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: { message: res.statusText } }));
    throw new Error(err?.error?.message ?? `HTTP ${res.status}`);
  }

  return res.json() as Promise<T>;
}

// ── Auth ───────────────────────────────────────────────────

export async function login(email: string, password: string): Promise<AuthTokens> {
  const data = await request<{
    success: boolean;
    data: { accessToken: string; refreshToken: string; expiresIn: number };
  }>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });

  const tokens: AuthTokens = {
    accessToken: data.data.accessToken,
    refreshToken: data.data.refreshToken,
    expiresAt: Date.now() + data.data.expiresIn * 1000,
  };

  await setTokens(tokens);
  return tokens;
}

export async function logout(refreshToken: string): Promise<void> {
  await request('/auth/logout', {
    method: 'POST',
    body: JSON.stringify({ refreshToken }),
  }).catch(() => {}); // Best-effort
  await clearTokens();
}

async function refreshAccessToken(refreshToken: string): Promise<boolean> {
  try {
    const data = await fetch(`${API_BASE}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    }).then((r) => r.json()) as { data: { accessToken: string; refreshToken: string; expiresIn: number } };

    await setTokens({
      accessToken: data.data.accessToken,
      refreshToken: data.data.refreshToken,
      expiresAt: Date.now() + data.data.expiresIn * 1000,
    });
    return true;
  } catch {
    return false;
  }
}

// ── Autofill API ───────────────────────────────────────────

export async function analyzeForm(
  domain: string,
  fields: FormField[],
): Promise<AnalyzeResponse['data']> {
  const strippedFields = fields.map(({ selector, label, type, placeholder, name }) => ({
    selector, label, type, placeholder, name,
  }));

  const res = await request<AnalyzeResponse>('/autofill/analyze', {
    method: 'POST',
    body: JSON.stringify({ domain, fields: strippedFields }),
  });
  return res.data;
}

export async function executeFill(
  sessionId: string,
  confirmedSelectors: string[],
): Promise<FillResponse['data']> {
  const res = await request<FillResponse>(`/autofill/sessions/${sessionId}/fill`, {
    method: 'POST',
    body: JSON.stringify({ confirmedSelectors }),
  });
  return res.data;
}

export async function rateSession(
  sessionId: string,
  accuracy: number,
  feedback?: string,
): Promise<void> {
  await request(`/autofill/sessions/${sessionId}/rate`, {
    method: 'POST',
    body: JSON.stringify({ accuracy, feedback }),
  });
}

// ── Profile ────────────────────────────────────────────────

export async function getMe(): Promise<{ id: string; email: string; fullName: string; plan: string }> {
  const res = await request<{ data: { id: string; email: string; fullName: string; plan: string } }>('/users/me');
  return res.data;
}

export async function getCompleteness(): Promise<{ score: number; missingSections: string[] }> {
  const res = await request<{ data: { score: number; missingSections: string[] } }>('/profile/completeness');
  return res.data;
}
