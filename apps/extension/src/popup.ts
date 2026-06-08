// ============================================================
// Formora Extension — Popup Script
// ============================================================

import {
  getTokens, login, logout, getMe, getCompleteness, analyzeForm,
} from './utils/api';
import { getDomainTrust, setDomainTrust, extractDomain } from './utils/trust';
import type { FieldMapping } from './types';

// ── State ──────────────────────────────────────────────────
let currentTab: chrome.tabs.Tab | null = null;
let currentDomain = '';
let currentSessionId: string | null = null;
let currentMappings: FieldMapping[] = [];

// ── DOM references ─────────────────────────────────────────
const authView    = document.getElementById('auth-view')!;
const mainView    = document.getElementById('main-view')!;
const headerActs  = document.getElementById('header-actions')!;
const emailInput  = document.getElementById('email-input') as HTMLInputElement;
const passInput   = document.getElementById('pass-input') as HTMLInputElement;
const loginBtn    = document.getElementById('login-btn') as HTMLButtonElement;
const loginLabel  = document.getElementById('login-label')!;
const loginError  = document.getElementById('login-error')!;
const logoutBtn   = document.getElementById('logout-btn')!;
const userName    = document.getElementById('user-name')!;
const userEmail   = document.getElementById('user-email')!;
const userAvatar  = document.getElementById('user-avatar')!;
const planBadge   = document.getElementById('plan-badge')!;
const compFill    = document.getElementById('completeness-fill')!;
const compPct     = document.getElementById('completeness-pct')!;
const domainEl    = document.getElementById('current-domain')!;
const trustSelect = document.getElementById('trust-select') as HTMLSelectElement;
const mappingsCon = document.getElementById('mappings-container')!;
const fillBtn     = document.getElementById('fill-btn') as HTMLButtonElement;
const analyzeBtn  = document.getElementById('analyze-btn') as HTMLButtonElement;

// ── Init ───────────────────────────────────────────────────

async function init() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  currentTab = tab ?? null;
  currentDomain = extractDomain(tab?.url ?? '');
  domainEl.textContent = currentDomain || 'Unknown';

  const tokens = await getTokens();
  if (tokens && tokens.expiresAt > Date.now()) {
    await showMainView();
  } else {
    showAuthView();
  }
}

// ── Auth ───────────────────────────────────────────────────

function showAuthView() {
  authView.style.display = 'block';
  mainView.style.display = 'none';
  headerActs.style.display = 'none';
}

async function showMainView() {
  authView.style.display = 'none';
  mainView.style.display = 'block';
  headerActs.style.display = 'flex';

  // Load user info + completeness in parallel
  const [user, comp] = await Promise.all([
    getMe().catch(() => null),
    getCompleteness().catch(() => null),
  ]);

  if (user) {
    const initials = (user.fullName ?? user.email).slice(0, 1).toUpperCase();
    userAvatar.textContent = initials;
    userName.textContent   = user.fullName ?? user.email;
    userEmail.textContent  = user.email;
    planBadge.textContent  = user.plan ?? 'Free';
  }

  if (comp) {
    compFill.style.width = `${comp.score}%`;
    compPct.textContent  = `${comp.score}%`;
  }

  // Trust
  const trust = await getDomainTrust(currentDomain);
  trustSelect.value = trust;

  // Try to get existing session from background
  await scanPage();
}

// ── Login ──────────────────────────────────────────────────

loginBtn.addEventListener('click', async () => {
  const email = emailInput.value.trim();
  const pass  = passInput.value;
  if (!email || !pass) return;

  loginBtn.disabled = true;
  loginLabel.innerHTML = '<span class="spinner"></span>';
  loginError.style.display = 'none';

  try {
    await login(email, pass);
    await showMainView();
  } catch (err) {
    loginError.textContent = (err as Error).message;
    loginError.style.display = 'block';
  } finally {
    loginBtn.disabled = false;
    loginLabel.textContent = 'Sign In';
  }
});

passInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') loginBtn.click(); });

// ── Logout ─────────────────────────────────────────────────

logoutBtn.addEventListener('click', async () => {
  const tokens = await getTokens();
  if (tokens) await logout(tokens.refreshToken);
  showAuthView();
});

// ── Trust ──────────────────────────────────────────────────

trustSelect.addEventListener('change', async () => {
  await setDomainTrust(currentDomain, trustSelect.value as 'trusted' | 'blocked' | 'ask');
});

// ── Page scan ─────────────────────────────────────────────

async function scanPage() {
  if (!currentTab?.id || !currentDomain) return;

  mappingsCon.innerHTML = '<div style="text-align:center;padding:16px;color:var(--muted);font-size:13px"><span class="spinner" style="border-top-color:var(--primary)"></span><br><br>Scanning page…</div>';

  try {
    // Get fields from content script
    const response = await chrome.tabs.sendMessage<unknown, { fields?: unknown }>(currentTab.id, {
      type: 'GET_FIELDS',
    }).catch(() => null);

    if (!response?.fields || !Array.isArray(response.fields) || response.fields.length === 0) {
      renderEmptyState('No fillable fields found on this page.');
      return;
    }

    // Analyze via API
    const result = await analyzeForm(currentDomain, response.fields as any);
    currentSessionId = result.sessionId;
    currentMappings  = result.mappings;
    renderMappings(result.mappings);
  } catch {
    renderEmptyState('Could not scan this page. Try refreshing.');
  }
}

analyzeBtn.addEventListener('click', scanPage);

// ── Render mappings ────────────────────────────────────────

function renderMappings(mappings: FieldMapping[]) {
  const matched = mappings.filter((m) => m.profileFieldKey);
  if (matched.length === 0) {
    renderEmptyState('No profile fields matched on this page.');
    return;
  }

  fillBtn.disabled = false;

  const html = matched.map((m) => {
    const confClass = m.confidence >= 85 ? '' : m.confidence >= 60 ? 'low' : 'none';
    return `
      <div class="mapping-item">
        <div class="mapping-left">
          <div class="mapping-dot ${confClass}"></div>
          <div>
            <div class="mapping-field">${escHtml(m.selector)}</div>
            <div class="mapping-key">${escHtml(m.profileFieldKey ?? '')}</div>
          </div>
        </div>
        <span class="conf-badge">${m.confidence}%</span>
      </div>
    `;
  }).join('');

  mappingsCon.innerHTML = `<div class="mappings-list">${html}</div><div style="font-size:11px;color:var(--muted);text-align:center;margin-top:8px">${matched.length} of ${mappings.length} fields matched</div>`;
}

function renderEmptyState(msg: string) {
  fillBtn.disabled = true;
  mappingsCon.innerHTML = `<div class="empty-state">
    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
      <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/>
    </svg>
    <p>${msg}</p>
  </div>`;
}

// ── Fill ───────────────────────────────────────────────────

fillBtn.addEventListener('click', async () => {
  if (!currentSessionId || currentMappings.length === 0) return;

  fillBtn.disabled = true;
  fillBtn.innerHTML = '<span class="spinner"></span> Filling…';

  try {
    const confirmedSelectors = currentMappings
      .filter((m) => m.profileFieldKey)
      .map((m) => m.selector);

    await chrome.runtime.sendMessage({
      type: 'TRIGGER_FILL',
      sessionId: currentSessionId,
      selectors: confirmedSelectors,
    });

    fillBtn.innerHTML = '✓ Filled!';
    fillBtn.style.background = 'linear-gradient(135deg, #22c55e, #16a34a)';
    setTimeout(() => {
      fillBtn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg> Fill Form`;
      fillBtn.style.background = '';
      fillBtn.disabled = false;
    }, 2500);
  } catch (err) {
    fillBtn.textContent = 'Fill Form';
    fillBtn.disabled = false;
    alert((err as Error).message);
  }
});

// ── Utils ──────────────────────────────────────────────────

function escHtml(str: string): string {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ── Start ──────────────────────────────────────────────────

init();
