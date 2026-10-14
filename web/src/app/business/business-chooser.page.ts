import { ChangeDetectionStrategy, Component, inject, OnInit, signal } from '@angular/core';
import { Router } from '@angular/router';
import { accountErrorMessages, validateBusinessName } from '../core/account-validation';
import { errorMessage } from '../core/error-messages';
import { AmountMode, BusinessSummary, QuantityMode } from '../core/models';
import { SessionService } from '../core/session.service';
import { AuthCardComponent } from '../auth/auth-card.component';
import { ErrorBannerComponent } from '../ui/error-banner.component';
import { IconComponent } from '../ui/icon.component';
import { inputValue } from '../ui/input-value';
import {
  amountOptions,
  ModePickerComponent,
  quantityOptions,
} from '../ui/mode-picker.component';

/// Elegir el negocio con el que se trabaja (RF-5) y crear uno nuevo (RF-79).
@Component({
  selector: 'app-business-chooser-page',
  imports: [AuthCardComponent, ErrorBannerComponent, IconComponent, ModePickerComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<app-auth-card
    [title]="hasBusinesses() ? 'Elige tu negocio' : 'Crea tu negocio'"
    [subtitle]="hasBusinesses() ? 'Con cuál quieres trabajar ahora' : 'Aún no tienes un negocio'"
  >
    <div class="space-y-5">
      @if (error()) {
        <app-error-banner [message]="error()!" />
      }
      @if (loading()) {
        <p class="py-6 text-center text-sm text-slate-500">Cargando tus negocios…</p>
      }
      @if (hasBusinesses()) {
        <ul class="space-y-2">
          @for (b of businesses(); track b.id) {
            <li>
              <button
                type="button"
                class="flex w-full items-center gap-3 rounded-2xl border border-slate-200 bg-white p-3 text-left transition hover:border-accent hover:bg-teal-50"
                [attr.data-test]="'business-' + b.id"
                (click)="choose(b)"
              >
                <span
                  class="flex h-11 w-11 items-center justify-center rounded-xl bg-brand text-accent"
                >
                  <app-icon name="store" />
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block truncate font-semibold text-brand">{{ b.name }}</span>
                  <span class="block text-xs text-slate-500">
                    {{ b.role === 'owner' ? 'Dueño' : 'Empleado' }}
                    @if (b.status === 'pending') {
                      · Pendiente de activación
                    } @else if (b.status === 'suspended') {
                      · Suspendido
                    }
                  </span>
                </span>
                <app-icon name="chevron" class="text-slate-400" />
              </button>
            </li>
          }
        </ul>
      }

      @if (!loading()) {
        <form class="space-y-4" novalidate (submit)="$event.preventDefault(); create()">
          <h2 class="text-base font-bold text-brand">Crear un negocio</h2>
          <div>
            <label class="field-label" for="name">Nombre del negocio</label>
            <input
              id="name"
              class="field"
              maxlength="60"
              data-test="create-name"
              [value]="name()"
              (input)="name.set(inputValue($event))"
            />
            @if (nameError()) {
              <p class="mt-1 text-sm font-semibold text-debt">{{ nameError() }}</p>
            }
          </div>
          <app-mode-picker
            title="Montos"
            hint="Ejemplo: L 25 o L 25.50"
            prefix="create-amount-"
            [options]="amountOptions"
            [value]="amount()"
            [error]="amountMissing() ? 'Elige cómo manejas los montos' : null"
            (chosen)="amount.set($any($event)); amountMissing.set(false)"
          />
          <app-mode-picker
            title="Cantidades"
            hint="Ejemplo: 2 libras o 0.5 libras"
            prefix="create-quantity-"
            [options]="quantityOptions"
            [value]="quantity()"
            [error]="quantityMissing() ? 'Elige cómo manejas las cantidades' : null"
            (chosen)="quantity.set($any($event)); quantityMissing.set(false)"
          />
          <button type="submit" class="btn-primary" data-test="create-submit" [disabled]="busy()">
            <app-icon name="plus" />
            {{ busy() ? 'Creando…' : 'Crear negocio' }}
          </button>
        </form>
      }
      <button type="button" class="link block w-full text-center text-sm" (click)="signOut()">
        Cerrar sesión
      </button>
    </div>
  </app-auth-card>`,
})
export class BusinessChooserPage implements OnInit {
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);

  protected readonly inputValue = inputValue;
  protected readonly amountOptions = amountOptions;
  protected readonly quantityOptions = quantityOptions;

  protected readonly businesses = signal<BusinessSummary[]>([]);
  protected readonly loading = signal(true);
  protected readonly hasBusinesses = () => this.businesses().length > 0;

  protected readonly name = signal('');
  protected readonly amount = signal<AmountMode | null>(null);
  protected readonly quantity = signal<QuantityMode | null>(null);
  protected readonly nameError = signal<string | null>(null);
  protected readonly amountMissing = signal(false);
  protected readonly quantityMissing = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly busy = signal(false);

  async ngOnInit(): Promise<void> {
    try {
      this.businesses.set(await this.session.loadBusinesses());
    } catch (e) {
      this.error.set(errorMessage(e));
    } finally {
      this.loading.set(false);
    }
  }

  protected async choose(business: BusinessSummary): Promise<void> {
    this.session.selectBusiness(business.id);
    await this.router.navigateByUrl('/');
  }

  protected async create(): Promise<void> {
    if (this.busy()) return;
    this.error.set(null);
    const nameError = validateBusinessName(this.name());
    const amount = this.amount();
    const quantity = this.quantity();
    this.nameError.set(nameError ? accountErrorMessages[nameError] : null);
    this.amountMissing.set(amount === null);
    this.quantityMissing.set(quantity === null);
    if (nameError || amount === null || quantity === null) return;

    this.busy.set(true);
    try {
      const created = await this.session.createBusiness({
        name: this.name().trim(),
        amountMode: amount,
        quantityMode: quantity,
      });
      this.session.selectBusiness(created.id);
      await this.router.navigateByUrl('/');
    } catch (e) {
      this.error.set(errorMessage(e));
    } finally {
      this.busy.set(false);
    }
  }

  protected async signOut(): Promise<void> {
    await this.session.logout();
    await this.router.navigateByUrl('/entrar');
  }
}
