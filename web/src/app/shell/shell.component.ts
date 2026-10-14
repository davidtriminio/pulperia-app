import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router, RouterOutlet } from '@angular/router';
import { ConnectivityService } from '../core/connectivity.service';
import { SessionService } from '../core/session.service';
import { IconComponent } from '../ui/icon.component';
import { BusinessBlockedComponent } from './business-blocked.component';

/// Marco de las pantallas del negocio: barra superior con el negocio activo y el menú de cuenta,
/// y aviso cuando no hay conexión (la web escribe directo en el servidor).
@Component({
  selector: 'app-shell',
  imports: [RouterOutlet, IconComponent, BusinessBlockedComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<header class="sticky top-0 z-10 bg-brand text-white shadow">
      <div class="mx-auto flex max-w-5xl items-center gap-3 px-4 py-3">
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/10 text-accent">
          <app-icon name="store" />
        </span>
        <div class="min-w-0 flex-1">
          <p class="truncate text-base font-bold leading-tight">
            {{ session.activeBusiness()?.name }}
          </p>
          <p class="truncate text-xs text-white/70">
            {{ session.isOwner() ? 'Dueño' : 'Empleado' }} · {{ session.email() }}
          </p>
        </div>
        <button
          type="button"
          class="flex items-center gap-1.5 rounded-lg px-2.5 py-2 text-sm font-semibold hover:bg-white/10"
          data-test="switch"
          (click)="switchBusiness()"
        >
          <app-icon name="swap" [size]="18" />
          <span class="hidden sm:inline">Cambiar de negocio</span>
        </button>
        <button
          type="button"
          class="flex items-center gap-1.5 rounded-lg px-2.5 py-2 text-sm font-semibold hover:bg-white/10"
          data-test="logout"
          (click)="logout()"
        >
          <app-icon name="log-out" [size]="18" />
          <span class="hidden sm:inline">Cerrar sesión</span>
        </button>
      </div>
      @if (!net.online()) {
        <div
          class="flex items-center justify-center gap-2 bg-amber-100 px-4 py-2 text-sm font-semibold text-amber-900"
          role="status"
        >
          <app-icon name="wifi-off" [size]="18" />
          Sin conexión. Conéctate a internet para continuar.
        </div>
      }
    </header>
    <main class="mx-auto max-w-5xl px-4 py-6">
      @if (blocked(); as status) {
        <app-business-blocked
          [status]="status"
          [stillBlocked]="stillBlocked()"
          (check)="check()"
          (switchBusiness)="switchBusiness()"
        />
      } @else {
        <router-outlet />
      }
    </main>`,
})
export class ShellComponent {
  protected readonly session = inject(SessionService);
  protected readonly net = inject(ConnectivityService);
  private readonly router = inject(Router);

  /// El negocio activo no se puede usar: pendiente de activación o suspendido (T194).
  protected readonly blocked = computed(() => {
    const status = this.session.activeBusiness()?.status;
    return status === 'pending' || status === 'suspended' ? status : null;
  });
  protected readonly stillBlocked = signal(false);

  protected async check(): Promise<void> {
    this.stillBlocked.set(false);
    try {
      await this.session.loadBusinesses();
    } catch {
      // Sin respuesta del servidor el aviso sigue igual.
    }
    this.stillBlocked.set(this.blocked() !== null);
  }

  protected async switchBusiness(): Promise<void> {
    this.session.selectBusiness(null);
    await this.router.navigateByUrl('/negocios');
  }

  protected async logout(): Promise<void> {
    await this.session.logout();
    await this.router.navigateByUrl('/entrar');
  }
}
