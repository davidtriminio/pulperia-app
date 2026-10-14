import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

/// Iconos de trazo dibujados en código (sin dependencias; principio 9).
const paths: Record<string, string> = {
  store: 'M3 9l1.5-5h15L21 9M3 9v11h18V9M3 9h18M9 20v-6h6v6',
  alert:
    'M12 9v4m0 4h.01M10.3 3.9L2.4 18a2 2 0 001.7 3h15.8a2 2 0 001.7-3L13.7 3.9a2 2 0 00-3.4 0z',
  'wifi-off':
    'M2 8.8a15 15 0 0119.9 0M5 12.5a10 10 0 0114 0M8.5 16.1a5 5 0 017 0M12 20h.01M3 3l18 18',
  clock: 'M12 6v6l4 2M12 21a9 9 0 100-18 9 9 0 000 18z',
  'log-out': 'M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9',
  swap: 'M7 4L3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7',
  plus: 'M12 5v14M5 12h14',
  check: 'M5 13l4 4L19 7',
  eye: 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12zM12 15a3 3 0 100-6 3 3 0 000 6z',
  'eye-off':
    'M3 3l18 18M10.6 10.6a3 3 0 004.2 4.2M9.9 5.1A10 10 0 0112 5c6.4 0 10 7 10 7a17 17 0 01-3.2 4.2M6.6 6.6C3.7 8.4 2 12 2 12s3.6 7 10 7a9.7 9.7 0 004.4-1',
  refresh: 'M21 12a9 9 0 11-3-6.7L21 8M21 3v5h-5',
  lock: 'M6 11h12v9H6zM8 11V8a4 4 0 018 0v3',
  chevron: 'M9 6l6 6-6 6',
};

@Component({
  selector: 'app-icon',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<svg
    [attr.width]="size()"
    [attr.height]="size()"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path [attr.d]="path()" />
  </svg>`,
  host: { class: 'inline-flex shrink-0' },
})
export class IconComponent {
  readonly name = input.required<string>();
  readonly size = input(20);
  protected readonly path = computed(() => paths[this.name()] ?? '');
}
