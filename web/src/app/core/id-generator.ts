import { Injectable } from '@angular/core';

/// El único generador de identificadores (D-21): UUID v7 (RFC 9562), 48 bits de milisegundos y el
/// resto aleatorio. Inyectable para que las pruebas lo sustituyan.
@Injectable({ providedIn: 'root' })
export class IdGenerator {
  next(): string {
    const bytes = new Uint8Array(16);
    crypto.getRandomValues(bytes);

    const now = Date.now();
    // 48 bits de tiempo, sin operaciones de bits de 32 bits que los truncarían.
    const high = Math.floor(now / 0x100000000);
    const low = now >>> 0;
    bytes[0] = (high >>> 8) & 0xff;
    bytes[1] = high & 0xff;
    bytes[2] = (low >>> 24) & 0xff;
    bytes[3] = (low >>> 16) & 0xff;
    bytes[4] = (low >>> 8) & 0xff;
    bytes[5] = low & 0xff;

    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  }
}
