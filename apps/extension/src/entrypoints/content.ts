// ============================================================
// Formora Extension — Content Script
// Runs on every web page:
// 1. Detects form fields
// 2. Reports to background worker
// 3. Injects values on fill command
// 4. Shows inline suggestion badges
// ============================================================

import type { FormField, ExtMessage } from '../types';

let detectedFields: FormField[] = [];
let currentSessionId: string | null = null;
const FORMORA_ATTR = 'data-formora-id';

export default defineContentScript({
  matches: ['<all_urls>'],
  main() {
    init();
  },
});

function init() {
  scanForms();

  // Re-scan on DOM mutations (SPAs like React/Vue/Angular)
  const observer = new MutationObserver(debounce(scanForms, 800));
  observer.observe(document.body, { childList: true, subtree: true });

  // Message Listener
  chrome.runtime.onMessage.addListener((message: ExtMessage, sender: chrome.runtime.MessageSender, sendResponse: (response?: any) => void) => {
    if (message.type === 'GET_FIELDS') {
      sendResponse({ fields: detectedFields });
      return true; // Keep channel open for response
    }
    if (message.type === 'FILL_VALUES') {
      fillFields(message.values);
    }
  });
}

// ── Form scanner ───────────────────────────────────────────

function scanForms() {
  const inputs = document.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>(
    'input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"]):not([type="file"]):not([type="password"]), textarea',
  );

  const fields: FormField[] = [];

  inputs.forEach((el, i) => {
    const selector = buildSelector(el, i);
    el.setAttribute(FORMORA_ATTR, selector);

    const field: FormField = {
      selector,
      label: getLabel(el),
      type: (el as HTMLInputElement).type ?? 'text',
      placeholder: el.placeholder ?? undefined,
      name: el.name ?? undefined,
    };

    fields.push(field);
  });

  if (fields.length === 0) return;
  if (JSON.stringify(fields.map((f) => f.selector)) === JSON.stringify(detectedFields.map((f) => f.selector))) {
    return; // No change
  }

  detectedFields = fields;
  const domain = window.location.hostname.replace(/^www\./, '');

  chrome.runtime.sendMessage<ExtMessage>({
    type: 'FORM_DETECTED',
    fields,
    domain,
  }).then((response) => {
    if (response?.action === 'analyzed' && response.mappings) {
      currentSessionId = response.sessionId;
      showFieldBadges(response.mappings);
    }
  }).catch(() => {}); // Extension may not be ready
}

// ── Field badges (inline indicators) ──────────────────────

function showFieldBadges(mappings: Array<{ selector: string; profileFieldKey: string | null; confidence: number }>) {
  // Remove old badges
  document.querySelectorAll('.formora-badge').forEach((b) => b.remove());

  for (const mapping of mappings) {
    if (!mapping.profileFieldKey) continue;

    const el = document.querySelector<HTMLElement>(`[${FORMORA_ATTR}="${mapping.selector}"]`);
    if (!el) continue;

    const badge = document.createElement('span');
    badge.className = 'formora-badge';
    badge.setAttribute('title', `Formora: ${mapping.profileFieldKey} (${mapping.confidence}%)`);
    badge.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="10"/></svg>`;

    const style = badge.style;
    style.cssText = `
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      color: #6366f1;
      cursor: pointer;
      z-index: 999999;
      display: flex;
      align-items: center;
      pointer-events: auto;
    `;

    // Position relative to field
    const wrapper = document.createElement('span');
    wrapper.style.cssText = 'position: relative; display: inline-block; width: 0; height: 0; overflow: visible;';
    wrapper.appendChild(badge);

    el.insertAdjacentElement('afterend', wrapper);
  }
}

function fillFields(values: Record<string, string | null>) {
  let filled = 0;

  for (const [selector, value] of Object.entries(values)) {
    if (value === null) continue;

    const el = document.querySelector<HTMLInputElement | HTMLTextAreaElement>(
      `[${FORMORA_ATTR}="${selector}"]`,
    );
    if (!el) continue;

    // Native input value setter (React/Vue compatible)
    const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype,
      'value',
    )?.set;

    if (nativeInputValueSetter) {
      nativeInputValueSetter.call(el, value);
    } else {
      el.value = value;
    }

    // Dispatch events so frameworks pick up the change
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));

    // Visual flash
    el.style.outline = '2px solid #6366f1';
    el.style.transition = 'outline 0.3s';
    setTimeout(() => { el.style.outline = ''; }, 1500);

    filled++;
  }

  showToast(`✓ Formora filled ${filled} field${filled !== 1 ? 's' : ''}`);
}

// ── Toast notification ─────────────────────────────────────

function showToast(message: string) {
  const existing = document.getElementById('formora-toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.id = 'formora-toast';
  toast.textContent = message;
  toast.style.cssText = `
    position: fixed;
    bottom: 24px;
    right: 24px;
    background: linear-gradient(135deg, #6366f1, #8b5cf6);
    color: white;
    padding: 12px 20px;
    border-radius: 12px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 14px;
    font-weight: 500;
    box-shadow: 0 8px 32px rgba(99, 102, 241, 0.4);
    z-index: 2147483647;
    animation: formora-slide-in 0.3s ease;
    max-width: 300px;
  `;

  const style = document.createElement('style');
  style.textContent = `
    @keyframes formora-slide-in {
      from { transform: translateY(100px); opacity: 0; }
      to   { transform: translateY(0);    opacity: 1; }
    }
  `;
  document.head.appendChild(style);
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

// ── Helpers ────────────────────────────────────────────────

function getLabel(el: HTMLInputElement | HTMLTextAreaElement): string {
  // 1. aria-label
  if (el.getAttribute('aria-label')) return el.getAttribute('aria-label')!;
  // 2. <label for="id">
  if (el.id) {
    const label = document.querySelector<HTMLLabelElement>(`label[for="${el.id}"]`);
    if (label) return label.textContent?.trim() ?? '';
  }
  // 3. Closest label ancestor
  const parent = el.closest('label');
  if (parent) return parent.textContent?.replace(el.value, '').trim() ?? '';
  // 4. Placeholder as fallback
  return el.placeholder ?? el.name ?? el.type;
}

// Build selector
function buildSelector(el: Element, index: number): string {
  if (el.id) return `#${CSS.escape(el.id)}`;
  if (el.getAttribute('name')) return `[name="${el.getAttribute('name')}"]`;
  return `[data-formora-index="${index}"]`;
}

function debounce<T extends (...args: unknown[]) => void>(fn: T, ms: number): T {
  let timer: ReturnType<typeof setTimeout>;
  return ((...args: unknown[]) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  }) as T;
}
