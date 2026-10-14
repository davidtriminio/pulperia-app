import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { SessionService } from '../core/session.service';
import { IconComponent } from '../ui/icon.component';

/// Inicio del negocio. Los clientes y los fiados llegan en los siguientes tramos de la web.
@Component({
  selector: 'app-home-page',
  imports: [IconComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="flex flex-col items-center py-16 text-center">
    <span
      class="mb-4 flex h-20 w-20 items-center justify-center rounded-3xl bg-white text-accent shadow-sm ring-1 ring-slate-200"
    >
      <app-icon name="store" [size]="40" />
    </span>
    <h2 class="text-xl font-bold text-brand">{{ session.activeBusiness()?.name }}</h2>
    <p class="mt-1 max-w-sm text-sm text-slate-600">
      Tu sesión está lista. Aquí aparecerán tus clientes y sus fiados.
    </p>
  </section>`,
})
export class HomePage {
  protected readonly session = inject(SessionService);
}
