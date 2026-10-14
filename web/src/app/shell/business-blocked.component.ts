import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';
import { IconComponent } from '../ui/icon.component';

/// Pantalla de un negocio que no puede usarse todavía: pendiente de activación (RF-102, D-30) o
/// suspendido (RF-98). La web exige conexión, así que lo único que se puede hacer es volver a
/// comprobar o cambiar de negocio.
@Component({
  selector: 'app-business-blocked',
  imports: [IconComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section
    class="mx-auto flex max-w-md flex-col items-center py-12 text-center"
    data-test="blocked"
  >
    <span
      class="mb-4 flex h-20 w-20 items-center justify-center rounded-3xl bg-white shadow-sm ring-1 ring-slate-200"
      [class.text-accent]="status() === 'pending'"
      [class.text-debt]="status() === 'suspended'"
    >
      <app-icon [name]="status() === 'pending' ? 'clock' : 'lock'" [size]="40" />
    </span>
    @if (status() === 'pending') {
      <h2 class="text-xl font-bold text-brand">Tu negocio está pendiente de activación</h2>
      <p class="mt-2 text-sm text-slate-600">
        Lo revisa quien administra la plataforma. Cuando lo active podrás registrar clientes y
        fiados.
      </p>
    } @else {
      <h2 class="text-xl font-bold text-brand">Negocio suspendido</h2>
      <p class="mt-2 text-sm text-slate-600">
        Este negocio está suspendido. Comunícate con quien administra la plataforma.
      </p>
    }
    @if (stillBlocked()) {
      <p class="mt-3 text-sm font-semibold text-debt" role="status">
        Todavía no está activo. Inténtalo más tarde.
      </p>
    }
    <div class="mt-6 flex flex-wrap justify-center gap-3">
      <button type="button" class="btn-secondary" data-test="check" (click)="check.emit()">
        <app-icon name="refresh" [size]="18" /> Comprobar ahora
      </button>
      <button type="button" class="btn-secondary" (click)="switchBusiness.emit()">
        <app-icon name="swap" [size]="18" /> Cambiar de negocio
      </button>
    </div>
  </section>`,
})
export class BusinessBlockedComponent {
  readonly status = input.required<'pending' | 'suspended'>();
  readonly stillBlocked = input(false);
  readonly check = output<void>();
  readonly switchBusiness = output<void>();
}
