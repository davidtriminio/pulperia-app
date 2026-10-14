import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import {
  AccountError,
  accountErrorMessages,
  validateBusinessName,
  validateEmail,
  validatePassword,
} from '../core/account-validation';
import { errorMessage } from '../core/error-messages';
import { AmountMode, QuantityMode } from '../core/models';
import { SessionService } from '../core/session.service';
import { ErrorBannerComponent } from '../ui/error-banner.component';
import { IconComponent } from '../ui/icon.component';
import { inputValue } from '../ui/input-value';
import {
  amountOptions,
  ModePickerComponent,
  quantityOptions,
} from '../ui/mode-picker.component';
import { AuthCardComponent } from './auth-card.component';

/// Crear la cuenta con su primer negocio (RF-1, RF-7, RF-78). Requiere conexión. El registro no
/// devuelve tokens: tras crearla se inicia sesión con los mismos datos.
@Component({
  selector: 'app-register-page',
  imports: [RouterLink, AuthCardComponent, ErrorBannerComponent, IconComponent, ModePickerComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<app-auth-card
    title="Crea tu cuenta"
    subtitle="Registra tu negocio para llevar sus fiados"
  >
    <form class="space-y-4" novalidate (submit)="$event.preventDefault(); submit()">
      @if (error()) {
        <app-error-banner [message]="error()!" />
      }
      <div>
        <label class="field-label" for="email">Correo electrónico</label>
        <input
          id="email"
          class="field"
          type="email"
          autocomplete="email"
          data-test="email"
          [value]="email()"
          (input)="email.set(inputValue($event))"
        />
        @if (emailError()) {
          <p class="mt-1 text-sm font-semibold text-debt">{{ message(emailError()!) }}</p>
        }
      </div>
      <div>
        <label class="field-label" for="password">Contraseña</label>
        <div class="relative">
          <input
            id="password"
            class="field pr-11"
            [type]="showPassword() ? 'text' : 'password'"
            autocomplete="new-password"
            data-test="password"
            [value]="password()"
            (input)="password.set(inputValue($event))"
          />
          <button
            type="button"
            class="absolute inset-y-0 right-0 px-3 text-slate-500"
            [attr.aria-label]="showPassword() ? 'Ocultar contraseña' : 'Mostrar contraseña'"
            (click)="showPassword.set(!showPassword())"
          >
            <app-icon [name]="showPassword() ? 'eye-off' : 'eye'" />
          </button>
        </div>
        <p class="mt-1 text-xs text-slate-500">Mínimo 8 caracteres</p>
        @if (passwordError()) {
          <p class="text-sm font-semibold text-debt">{{ message(passwordError()!) }}</p>
        }
      </div>
      <div>
        <label class="field-label" for="business">Nombre del negocio</label>
        <input
          id="business"
          class="field"
          maxlength="60"
          data-test="business"
          [value]="business()"
          (input)="business.set(inputValue($event))"
        />
        @if (businessError()) {
          <p class="mt-1 text-sm font-semibold text-debt">{{ message(businessError()!) }}</p>
        }
      </div>
      <app-mode-picker
        title="Montos"
        hint="Ejemplo: L 25 o L 25.50"
        prefix="amount-"
        [options]="amountOptions"
        [value]="amount()"
        [error]="amountMissing() ? 'Elige cómo manejas los montos' : null"
        (chosen)="amount.set($any($event)); amountMissing.set(false)"
      />
      <app-mode-picker
        title="Cantidades"
        hint="Ejemplo: 2 libras o 0.5 libras"
        prefix="quantity-"
        [options]="quantityOptions"
        [value]="quantity()"
        [error]="quantityMissing() ? 'Elige cómo manejas las cantidades' : null"
        (chosen)="quantity.set($any($event)); quantityMissing.set(false)"
      />
      <button type="submit" class="btn-primary" data-test="submit" [disabled]="busy()">
        {{ busy() ? 'Creando…' : 'Crear cuenta' }}
      </button>
      <p class="text-center text-sm text-slate-600">
        ¿Ya tienes cuenta? <a class="link" routerLink="/entrar">Entrar</a>
      </p>
    </form>
  </app-auth-card>`,
})
export class RegisterPage {
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);

  protected readonly inputValue = inputValue;
  protected readonly amountOptions = amountOptions;
  protected readonly quantityOptions = quantityOptions;

  protected readonly email = signal('');
  protected readonly password = signal('');
  protected readonly business = signal('');
  protected readonly amount = signal<AmountMode | null>(null);
  protected readonly quantity = signal<QuantityMode | null>(null);
  protected readonly showPassword = signal(false);
  protected readonly emailError = signal<AccountError | null>(null);
  protected readonly passwordError = signal<AccountError | null>(null);
  protected readonly businessError = signal<AccountError | null>(null);
  protected readonly amountMissing = signal(false);
  protected readonly quantityMissing = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly busy = signal(false);

  protected message(code: AccountError): string {
    return accountErrorMessages[code];
  }

  protected async submit(): Promise<void> {
    if (this.busy()) return;
    this.error.set(null);
    const emailError = validateEmail(this.email());
    const passwordError = validatePassword(this.password());
    const businessError = validateBusinessName(this.business());
    const amount = this.amount();
    const quantity = this.quantity();
    this.emailError.set(emailError);
    this.passwordError.set(passwordError);
    this.businessError.set(businessError);
    this.amountMissing.set(amount === null);
    this.quantityMissing.set(quantity === null);
    if (emailError || passwordError || businessError || amount === null || quantity === null) {
      return;
    }

    this.busy.set(true);
    try {
      const email = this.email().trim();
      await this.session.register({
        email,
        password: this.password(),
        businessName: this.business().trim(),
        amountMode: amount,
        quantityMode: quantity,
      });
      await this.session.login(email, this.password());
      await this.router.navigateByUrl(await this.session.openAfterSignIn());
    } catch (e) {
      this.error.set(errorMessage(e));
    } finally {
      this.busy.set(false);
    }
  }
}
