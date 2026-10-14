import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';

export interface ModeOption {
  value: string;
  label: string;
}

/// Elección entre pocas opciones, con el valor elegido resaltado (montos y cantidades, RF-7).
@Component({
  selector: 'app-mode-picker',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<fieldset class="space-y-1">
    <legend class="text-sm font-semibold text-brand">{{ title() }}</legend>
    <div class="grid grid-cols-2 gap-2">
      @for (option of options(); track option.value) {
        <button
          type="button"
          class="rounded-xl border-2 px-3 py-2 text-sm font-semibold transition"
          [class.border-accent]="value() === option.value"
          [class.bg-teal-50]="value() === option.value"
          [class.text-brand]="value() === option.value"
          [class.border-slate-300]="value() !== option.value"
          [class.text-slate-600]="value() !== option.value"
          [attr.aria-pressed]="value() === option.value"
          [attr.data-test]="prefix() + option.value"
          (click)="chosen.emit(option.value)"
        >
          {{ option.label }}
        </button>
      }
    </div>
    <p class="text-xs text-slate-500">{{ hint() }}</p>
    @if (error()) {
      <p class="text-sm font-semibold text-debt">{{ error() }}</p>
    }
  </fieldset>`,
})
export class ModePickerComponent {
  readonly title = input.required<string>();
  readonly hint = input('');
  readonly options = input.required<ModeOption[]>();
  readonly value = input<string | null>(null);
  readonly error = input<string | null>(null);
  readonly prefix = input('');
  readonly chosen = output<string>();
}

export const amountOptions: ModeOption[] = [
  { value: 'integer', label: 'Enteros' },
  { value: 'two_decimals', label: 'Con centavos' },
];

export const quantityOptions: ModeOption[] = [
  { value: 'integer', label: 'Enteras' },
  { value: 'fractional', label: 'Con decimales' },
];
