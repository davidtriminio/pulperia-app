import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { environment } from '../../environments/environment';
import {
  BusinessSummary,
  CreateBusinessRequest,
  Registered,
  RegisterRequest,
  Tokens,
} from './models';

const storageKey = 'pulperia.session';

interface Stored {
  tokens: Tokens;
  email: string;
  activeBusinessId: string | null;
}

/// La sesión de quien usa la web: tokens, correo y negocio activo. Vive en `sessionStorage`, así
/// que se pierde al cerrar la pestaña (decisión del usuario, 2026-10-13). El interceptor
/// (`apiInterceptor`) pone el token y el negocio en cada petición y llama a [refresh] ante un 401.
@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly http = inject(HttpClient);

  private readonly tokensState = signal<Tokens | null>(null);
  readonly email = signal<string | null>(null);
  readonly activeBusinessId = signal<string | null>(null);
  readonly businesses = signal<BusinessSummary[] | null>(null);

  readonly isSignedIn = computed(() => this.tokensState() !== null);
  readonly activeBusiness = computed(
    () => this.businesses()?.find((b) => b.id === this.activeBusinessId()) ?? null,
  );
  readonly isOwner = computed(() => this.activeBusiness()?.role === 'owner');

  private refreshing: Promise<boolean> | null = null;

  constructor() {
    const stored = readStored();
    if (stored) {
      this.tokensState.set(stored.tokens);
      this.email.set(stored.email);
      this.activeBusinessId.set(stored.activeBusinessId);
    }
  }

  accessToken(): string | null {
    return this.tokensState()?.accessToken ?? null;
  }

  async register(request: RegisterRequest): Promise<Registered> {
    return firstValueFrom(this.http.post<Registered>(`${environment.apiUrl}/api/auth/register`, request));
  }

  async login(email: string, password: string): Promise<void> {
    const tokens = await firstValueFrom(
      this.http.post<Tokens>(`${environment.apiUrl}/api/auth/login`, { email, password }),
    );
    this.tokensState.set(tokens);
    this.email.set(email);
    this.activeBusinessId.set(null);
    this.businesses.set(null);
    this.persist();
  }

  /// Renueva los tokens (RF-4). Varias peticiones que fallan a la vez comparten una sola
  /// renovación. Devuelve `false` (y cierra la sesión) si el servidor la rechaza.
  refresh(): Promise<boolean> {
    this.refreshing ??= this.doRefresh().finally(() => (this.refreshing = null));
    return this.refreshing;
  }

  private async doRefresh(): Promise<boolean> {
    const current = this.tokensState();
    if (!current) return false;
    try {
      const tokens = await firstValueFrom(
        this.http.post<Tokens>(`${environment.apiUrl}/api/auth/refresh`, {
          refreshToken: current.refreshToken,
        }),
      );
      this.tokensState.set(tokens);
      this.persist();
      return true;
    } catch {
      this.clear();
      return false;
    }
  }

  async logout(): Promise<void> {
    try {
      await firstValueFrom(this.http.post(`${environment.apiUrl}/api/auth/logout`, null));
    } catch {
      // Aunque el servidor no responda, la sesión de este navegador se cierra igual.
    }
    this.clear();
  }

  clear(): void {
    this.tokensState.set(null);
    this.email.set(null);
    this.activeBusinessId.set(null);
    this.businesses.set(null);
    try {
      sessionStorage.removeItem(storageKey);
    } catch {
      // Sin almacenamiento disponible no hay nada que borrar.
    }
  }

  async loadBusinesses(): Promise<BusinessSummary[]> {
    const list = await firstValueFrom(
      this.http.get<BusinessSummary[]>(`${environment.apiUrl}/api/businesses`),
    );
    this.businesses.set(list);
    return list;
  }

  async createBusiness(request: CreateBusinessRequest): Promise<BusinessSummary> {
    const created = await firstValueFrom(
      this.http.post<BusinessSummary>(`${environment.apiUrl}/api/businesses`, request),
    );
    this.businesses.update((list) => [...(list ?? []), created]);
    return created;
  }

  selectBusiness(id: string | null): void {
    this.activeBusinessId.set(id);
    this.persist();
  }

  private persist(): void {
    const tokens = this.tokensState();
    if (!tokens) return;
    const stored: Stored = {
      tokens,
      email: this.email() ?? '',
      activeBusinessId: this.activeBusinessId(),
    };
    try {
      sessionStorage.setItem(storageKey, JSON.stringify(stored));
    } catch {
      // Sin almacenamiento la sesión dura lo que dure la pestaña cargada.
    }
  }
}

function readStored(): Stored | null {
  try {
    const raw = sessionStorage.getItem(storageKey);
    if (!raw) return null;
    const value = JSON.parse(raw) as Stored;
    return value?.tokens?.accessToken ? value : null;
  } catch {
    return null;
  }
}
