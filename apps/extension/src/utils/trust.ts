// ============================================================
// Formora Extension — Trust Store
// Per-domain trust settings: trusted / blocked / ask
// ============================================================

import type { TrustConfig } from '../types';

export async function getTrustConfig(): Promise<TrustConfig> {
  const result = await chrome.storage.sync.get('trust');
  return (result.trust as TrustConfig) ?? {};
}

export async function setDomainTrust(
  domain: string,
  trust: 'trusted' | 'blocked' | 'ask',
): Promise<void> {
  const config = await getTrustConfig();
  config[domain] = trust;
  await chrome.storage.sync.set({ trust: config });
}

export async function getDomainTrust(
  domain: string,
): Promise<'trusted' | 'blocked' | 'ask'> {
  const config = await getTrustConfig();
  return config[domain] ?? 'ask';
}

export function extractDomain(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
}
