// ============================================================
// Formora Extension — Background Service Worker
// Handles: auth state, messaging, tab coordination
// ============================================================

import { getTokens, analyzeForm, executeFill } from '../utils/api';
import { getDomainTrust } from '../utils/trust';
import type { ExtMessage } from '../types';

export default defineBackground({
  main() {
    // ── Extension install / update ─────────────────────────────
    chrome.runtime.onInstalled.addListener((details: chrome.runtime.InstalledDetails) => {
      if (details.reason === 'install') {
        chrome.tabs.create({ url: chrome.runtime.getURL('popup.html') });
      }
    });

    // ── Message handler ────────────────────────────────────────
    chrome.runtime.onMessage.addListener(
      (message: ExtMessage, sender: chrome.runtime.MessageSender, sendResponse: (response?: any) => void) => {
        handleMessage(message, sender).then(sendResponse).catch((err) => {
          console.error('[Formora BG]', err);
          sendResponse({ error: err.message });
        });
        return true; // Keep channel open for async response
      },
    );

    // ── Tab URL change: clear badge ────────────────────────────
    chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
      if (changeInfo.status === 'loading') {
        chrome.action.setBadgeText({ text: '', tabId });
      }
    });
  },
});

async function handleMessage(
  message: ExtMessage,
  sender: chrome.runtime.MessageSender,
) {
  switch (message.type) {
    // ── Auth status check ──────────────────────────────────
    case 'GET_AUTH_STATUS': {
      const tokens = await getTokens();
      const isLoggedIn = !!tokens && tokens.expiresAt > Date.now();
      return { isLoggedIn };
    }

    // ── Form detected by content script ───────────────────
    case 'FORM_DETECTED': {
      const tokens = await getTokens();
      if (!tokens) return { action: 'not_logged_in' };

      const trust = await getDomainTrust(message.domain);
      if (trust === 'blocked') return { action: 'blocked' };

      if (trust === 'ask') {
        // Show badge to indicate form is available
        if (sender.tab?.id) {
          chrome.action.setBadgeText({ text: '!', tabId: sender.tab.id });
          chrome.action.setBadgeBackgroundColor({ color: '#6366f1', tabId: sender.tab.id });
        }
        return { action: 'ask' };
      }

      // Trusted — auto-analyze
      const result = await analyzeForm(message.domain, message.fields);
      if (sender.tab?.id) {
        chrome.action.setBadgeText({
          text: String(result.mappings.filter((m) => m.profileFieldKey).length),
          tabId: sender.tab.id,
        });
        chrome.action.setBadgeBackgroundColor({ color: '#22c55e', tabId: sender.tab.id });
      }
      return { action: 'analyzed', ...result };
    }

    // ── Execute fill triggered from popup ────────────────
    case 'TRIGGER_FILL': {
      const result = await executeFill(message.sessionId, message.selectors);
      // Forward values to content script on active tab
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        chrome.tabs.sendMessage(tab.id, {
          type: 'FILL_VALUES',
          values: result.values,
        });
      }
      return { filled: result.filledCount };
    }

    default:
      return { error: 'Unknown message type' };
  }
}
