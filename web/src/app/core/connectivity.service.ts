import { Injectable, signal } from '@angular/core';

/// Si el navegador cree que hay conexión. La web exige conexión (principio 2): sin ella toda
/// escritura se bloquea con un aviso en español, antes de salir a la red.
@Injectable({ providedIn: 'root' })
export class ConnectivityService {
  readonly online = signal(typeof navigator === 'undefined' ? true : navigator.onLine);

  constructor() {
    if (typeof window !== 'undefined') {
      window.addEventListener('online', () => this.online.set(true));
      window.addEventListener('offline', () => this.online.set(false));
    }
  }
}
