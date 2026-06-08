// ============================================================
// Formora — Encryption Service
// AES-256-GCM authenticated encryption for PII profile fields
// ============================================================

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;   // 96-bit IV for GCM
const TAG_BYTES = 16;  // 128-bit auth tag

@Injectable()
export class EncryptionService {
  private readonly logger = new Logger(EncryptionService.name);
  private readonly key: Buffer;

  constructor(private config: ConfigService) {
    const secret = this.config.getOrThrow<string>('ENCRYPTION_KEY');
    // Derive a 32-byte key from whatever secret is provided
    this.key = crypto.createHash('sha256').update(secret).digest();
  }

  /**
   * Encrypts plaintext → base64 string: iv:ciphertext:tag
   */
  encrypt(plaintext: string): string {
    const iv = crypto.randomBytes(IV_BYTES);
    const cipher = crypto.createCipheriv(ALGORITHM, this.key, iv, {
      authTagLength: TAG_BYTES,
    });

    const encrypted = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();

    // Pack as: iv(12) | tag(16) | ciphertext
    const packed = Buffer.concat([iv, tag, encrypted]);
    return packed.toString('base64');
  }

  /**
   * Decrypts base64 encoded iv:ciphertext:tag → plaintext
   */
  decrypt(encoded: string): string {
    const packed = Buffer.from(encoded, 'base64');
    const iv = packed.subarray(0, IV_BYTES);
    const tag = packed.subarray(IV_BYTES, IV_BYTES + TAG_BYTES);
    const ciphertext = packed.subarray(IV_BYTES + TAG_BYTES);

    const decipher = crypto.createDecipheriv(ALGORITHM, this.key, iv, {
      authTagLength: TAG_BYTES,
    });
    decipher.setAuthTag(tag);

    return decipher.update(ciphertext) + decipher.final('utf8');
  }

  /**
   * Safe decrypt — returns null instead of throwing on failure
   */
  safeDecrypt(encoded: string): string | null {
    try {
      return this.decrypt(encoded);
    } catch {
      this.logger.warn('Decryption failed — data may be corrupted or key mismatch');
      return null;
    }
  }
}
