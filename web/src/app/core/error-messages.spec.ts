import { ApiError, OfflineError, SessionExpiredError } from './api-error';
import { errorMessage, errorMessageForCode } from './error-messages';

describe('errorMessage', () => {
  it('traduce el código estable de la API al español', () => {
    expect(errorMessage(new ApiError(401, 'invalid_credentials', ['invalid_credentials']))).toBe(
      'Correo o contraseña incorrectos',
    );
    expect(errorMessageForCode('email_taken')).toBe('Ya existe una cuenta con ese correo');
  });

  it('avisa de la falta de conexión y de la sesión terminada', () => {
    expect(errorMessage(new OfflineError())).toBe(
      'Sin conexión. Conéctate a internet para continuar.',
    );
    expect(errorMessage(new SessionExpiredError())).toBe(
      'Tu sesión terminó. Inicia sesión de nuevo.',
    );
  });

  it('da un mensaje genérico para un código desconocido y otro para el servidor', () => {
    expect(errorMessage(new ApiError(400, 'algo_nuevo', ['algo_nuevo']))).toBe(
      'Algo salió mal. Inténtalo de nuevo.',
    );
    expect(errorMessage(new ApiError(500, 'internal_error', ['internal_error']))).toBe(
      'El servidor tuvo un problema. Inténtalo de nuevo en unos minutos.',
    );
    expect(errorMessage(new Error('x'))).toBe('Algo salió mal. Inténtalo de nuevo.');
  });

  it('tiene mensaje para los avisos de negocio y cuenta (T194)', () => {
    expect(errorMessageForCode('business_pending')).toContain('activ');
    expect(errorMessageForCode('business_suspended')).toContain('suspendido');
    expect(errorMessageForCode('account_suspended')).toContain('cuenta está suspendida');
  });
});
