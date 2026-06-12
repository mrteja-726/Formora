// ============================================================
// Encryption Service — Unit Tests
// ============================================================

import { EncryptionService } from './encryption.service';
import { ConfigService } from '@nestjs/config';

describe('EncryptionService', () => {
  let service: EncryptionService;

  beforeAll(() => {
    const config = {
      getOrThrow: () => 'test-secret-key-for-unit-tests-only',
    } as any as ConfigService;
    service = new EncryptionService(config);
  });

  it('should encrypt and decrypt a string', () => {
    const plaintext = 'Jane Doe';
    const encrypted = service.encrypt(plaintext);
    expect(encrypted).not.toEqual(plaintext);
    expect(service.decrypt(encrypted)).toEqual(plaintext);
  });

  it('should produce different ciphertext for same input (random IV)', () => {
    const plaintext = 'jane@example.com';
    const enc1 = service.encrypt(plaintext);
    const enc2 = service.encrypt(plaintext);
    expect(enc1).not.toEqual(enc2); // different IVs
    expect(service.decrypt(enc1)).toEqual(plaintext);
    expect(service.decrypt(enc2)).toEqual(plaintext);
  });

  it('should handle special characters and unicode', () => {
    const plaintext = '日本語テスト 🔒 Ünïcödé';
    expect(service.decrypt(service.encrypt(plaintext))).toEqual(plaintext);
  });

  it('safeDecrypt should return null on tampered data', () => {
    const result = service.safeDecrypt('definitely-not-valid-base64!!');
    expect(result).toBeNull();
  });

  it('should encrypt empty string', () => {
    const plaintext = '';
    expect(service.decrypt(service.encrypt(plaintext))).toEqual(plaintext);
  });
});
