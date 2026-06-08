// ============================================================
// Formora Extension — Local Synchronization Client
// Connects to Formora Desktop App WebSocket Server
// ============================================================

import { getTokens, setTokens, clearTokens } from './api';
import type { AuthTokens } from '../types';

let ws: WebSocket | null = null;
let reconnectTimer: any = null;
const SYNC_URL = 'ws://127.0.0.1:19190';
let isConnecting = false;

export function initSyncClient() {
  connect();

  // Listen for local storage changes to sync out to desktop
  chrome.storage.onChanged.addListener((changes, namespace) => {
    if (namespace === 'local' && changes.auth) {
      const newTokens = changes.auth.newValue as AuthTokens | undefined;
      sendAuthToDesktop(newTokens || null);
    }
  });
}

function connect() {
  if (ws || isConnecting) return;
  isConnecting = true;

  console.log('[Formora Sync] Connecting to desktop app...');
  ws = new WebSocket(SYNC_URL);

  ws.onopen = async () => {
    isConnecting = false;
    console.log('[Formora Sync] Connected to desktop app.');
    // Clear reconnect timer
    if (reconnectTimer) {
      clearInterval(reconnectTimer);
      reconnectTimer = null;
    }

    // Immediately send current extension auth state to desktop on connect
    const tokens = await getTokens();
    sendAuthToDesktop(tokens);
  };

  ws.onmessage = async (event) => {
    try {
      const msg = JSON.parse(event.data);
      console.log('[Formora Sync] Received message:', msg.type);

      if (msg.type === 'AUTH_SYNC') {
        const localTokens = await getTokens();
        // Sync only if tokens are different or newer to prevent loop
        if (
          !localTokens ||
          localTokens.accessToken !== msg.accessToken ||
          localTokens.refreshToken !== msg.refreshToken
        ) {
          if (msg.accessToken && msg.refreshToken) {
            await setTokens({
              accessToken: msg.accessToken,
              refreshToken: msg.refreshToken,
              expiresAt: msg.expiresAt || (Date.now() + 15 * 60 * 1000),
            });
            console.log('[Formora Sync] Storage synced from desktop app.');
          } else {
            await clearTokens();
            console.log('[Formora Sync] Storage cleared from desktop app.');
          }
        }
      } else if (msg.type === 'TRIGGER_DESKTOP_FILL') {
        // Desktop triggered a fill event for the active web page
        const values = msg.values as Record<string, string | null>;
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        if (tab?.id) {
          chrome.tabs.sendMessage(tab.id, {
            type: 'FILL_VALUES',
            values,
          }).catch((e) => console.warn('[Formora Sync] Failed to send fill message to content script', e));
        }
      }
    } catch (err) {
      console.error('[Formora Sync] Error processing websocket message', err);
    }
  };

  ws.onclose = () => {
    isConnecting = false;
    ws = null;
    console.log('[Formora Sync] Disconnected from desktop app. Retrying in 5s...');
    scheduleReconnect();
  };

  ws.onerror = (err) => {
    // Fail silently, connection state handled in onclose
    isConnecting = false;
  };
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setInterval(() => {
    connect();
  }, 5000);
}

function sendAuthToDesktop(tokens: AuthTokens | null) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;

  try {
    const payload = tokens
      ? {
          type: 'AUTH_SYNC',
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresAt: tokens.expiresAt,
        }
      : {
          type: 'AUTH_SYNC',
          accessToken: null,
          refreshToken: null,
          expiresAt: null,
        };

    ws.send(JSON.stringify(payload));
    console.log('[Formora Sync] Synced auth state with desktop app.');
  } catch (err) {
    console.error('[Formora Sync] Failed to send auth sync payload', err);
  }
}
