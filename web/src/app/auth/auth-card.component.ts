import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { IconComponent } from '../ui/icon.component';

/// Marco de las pantallas de cuenta: marca arriba, título y subtítulo, y el contenido en una
/// tarjeta centrada.
@Component({
  selector: 'app-auth-card',
  imports: [IconComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<main class="flex min-h-dvh flex-col items-center justify-center px-4 py-8">
    <div class="w-full max-w-md">
      <div class="mb-6 flex flex-col items-center text-center">
        <span
          class="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-brand text-accent"
        >
          <app-icon name="store" [size]="30" />
        </span>
        <h1 class="text-2xl font-bold text-brand">{{ title() }}</h1>
        @if (subtitle()) {
          <p class="mt-1 text-sm text-slate-600">{{ subtitle() }}</p>
        }
      </div>
      <div class="card">
        <ng-content />
      </div>
    </div>
  </main>`,
})
export class AuthCardComponent {
  readonly title = input.required<string>();
  readonly subtitle = input('');
}
