import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { accountErrorMessages, AccountError, validateEmail } from '../core/account-validation';
import { errorMessage } from '../core/error-messages';
import { SessionService } from '../core/session.service';
import { ErrorBannerComponent } from '../ui/error-banner.component';
import { IconComponent } from '../ui/icon.component';
import { inputValue } from '../ui/input-value';
import { AuthCardComponent } from './auth-card.component';

/// Inicio de sesión (RF-3). Requiere conexión.
@Component({
  selector: 'app-login-page',
  imports: [RouterLink, AuthCardComponent, ErrorBannerComponent, IconComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<app-auth-card
    title="Inicia sesión"
    subtitle="Entra para ver los fiados de tu negocio"
  >
    <form class="space-y-4" novalidate (submit)="$event.preventDefault(); submit()">
      @if (error() ?? session.notice()) {
        <app-error-banner [message]="(error() ?? session.notice())!" />
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
            autocomplete="current-password"
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
        @if (passwordError()) {
          <p class="mt-1 text-sm font-semibold text-debt">{{ message(passwordError()!) }}</p>
        }
      </div>
      <button type="submit" class="btn-primary" data-test="submit" [disabled]="busy()">
        {{ busy() ? 'Entrando…' : 'Entrar' }}
      </button>
      <p class="text-center text-sm text-slate-600">
        ¿No tienes cuenta? <a class="link" routerLink="/registro">Crear una cuenta</a>
      </p>
    </form>
  </app-auth-card>`,
})
export class LoginPage {
  protected readonly session = inject(SessionService);
  private readonly router = inject(Router);

  protected readonly inputValue = inputValue;
  protected readonly email = signal('');
  protected readonly password = signal('');
  protected readonly showPassword = signal(false);
  protected readonly emailError = signal<AccountError | null>(null);
  protected readonly passwordError = signal<AccountError | null>(null);
  protected readonly error = signal<string | null>(null);
  protected readonly busy = signal(false);

  protected message(code: AccountError): string {
    return accountErrorMessages[code];
  }

  protected async submit(): Promise<void> {
    if (this.busy()) return;
    this.error.set(null);
    this.session.notice.set(null);
    const emailError = validateEmail(this.email());
    // Al entrar solo se exige que no esté vacía: el largo mínimo es cosa del registro.
    const passwordError: AccountError | null = this.password() === '' ? 'passwordRequired' : null;
    this.emailError.set(emailError);
    this.passwordError.set(passwordError);
    if (emailError || passwordError) return;

    this.busy.set(true);
    try {
      await this.session.login(this.email().trim(), this.password());
      const next = await this.session.openAfterSignIn();
      await this.router.navigateByUrl(next);
    } catch (e) {
      this.error.set(errorMessage(e));
    } finally {
      this.busy.set(false);
    }
  }
}
