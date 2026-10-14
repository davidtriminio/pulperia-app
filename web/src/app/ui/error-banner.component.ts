import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { IconComponent } from './icon.component';

/// Tarjeta de error clara y en español: franja, icono y texto en negrita (como el móvil).
@Component({
  selector: 'app-error-banner',
  imports: [IconComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div
    role="alert"
    class="flex items-start gap-3 rounded-xl border-l-4 border-debt bg-red-50 p-3 text-sm font-semibold text-debt"
  >
    <app-icon name="alert" [size]="20" />
    <span>{{ message() }}</span>
  </div>`,
})
export class ErrorBannerComponent {
  readonly message = input.required<string>();
}
