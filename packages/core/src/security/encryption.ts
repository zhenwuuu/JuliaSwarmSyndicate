import { randomBytes, createCipheriv, createDecipheriv, createHash, timingSafeEqual } from 'crypto';

export interface EncryptionConfig {
  algorithm?: string;
  keyLength?: number;
  ivLength?: number;
}

export class EncryptionService {
  private algorithm: string;
  private keyLength: number;
  private ivLength: number;

  constructor(config: EncryptionConfig = {}) {
    this.algorithm = config.algorithm || 'aes-256-gcm';
    this.keyLength = config.keyLength || 32;
    this.ivLength = config.ivLength || 16;
  }

  generateKey(): Buffer {
    return randomBytes(this.keyLength);
  }

  private generateIV(): Buffer {
    return randomBytes(this.ivLength);
  }

  deriveKey(password: string, salt?: Buffer): Buffer {
    const saltBuffer = salt || randomBytes(16);
    return createHash('sha256')
      .update(Buffer.concat([Buffer.from(password), saltBuffer]))
      .digest();
  }

  encrypt(data: string | Buffer, key: Buffer): {
    encrypted: Buffer;
    iv: Buffer;
    authTag?: Buffer;
  } {
    const iv = this.generateIV();
    const cipher = createCipheriv(this.algorithm, key, iv);

    const encrypted = Buffer.concat([
      cipher.update(typeof data === 'string' ? Buffer.from(data) : data),
      cipher.final()
    ]);

    return {
      encrypted,
      iv,
      authTag: (cipher as any).getAuthTag?.()
    };
  }

  decrypt(
    encrypted: Buffer,
    key: Buffer,
    iv: Buffer,
    authTag?: Buffer
  ): Buffer {
    const decipher = createDecipheriv(this.algorithm, key, iv);

    if (authTag && (decipher as any).setAuthTag) {
      (decipher as any).setAuthTag(authTag);
    }

    return Buffer.concat([
      decipher.update(encrypted),
      decipher.final()
    ]);
  }

  encryptObject(obj: any, key: Buffer): {
    encrypted: string;
    iv: string;
    authTag?: string;
  } {
    const data = JSON.stringify(obj);
    const result = this.encrypt(data, key);

    return {
      encrypted: result.encrypted.toString('base64'),
      iv: result.iv.toString('base64'),
      authTag: result.authTag?.toString('base64')
    };
  }

  decryptObject<T>(
    encrypted: string,
    key: Buffer,
    iv: string,
    authTag?: string
  ): T {
    const decrypted = this.decrypt(
      Buffer.from(encrypted, 'base64'),
      key,
      Buffer.from(iv, 'base64'),
      authTag ? Buffer.from(authTag, 'base64') : undefined
    );

    return JSON.parse(decrypted.toString());
  }

  // Utility method for secure comparison
  compareBuffers(a: Buffer, b: Buffer): boolean {
    if (a.length !== b.length) return false;
    return timingSafeEqual(a, b);
  }
} 