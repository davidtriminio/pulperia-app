import { HttpErrorResponse, HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, from, Observable, switchMap, throwError } from 'rxjs';
import { environment } from '../../environments/environment';
import { ApiError, OfflineError, SessionExpiredError } from './api-error';
import { ConnectivityService } from './connectivity.service';
import { errorMessageForCode } from './error-messages';
import { SessionService } from './session.service';

/// Rutas que no llevan token: ahí un 401 es un error normal (por ejemplo, contraseña errónea).
const anonymous = ['/api/auth/register', '/api/auth/login', '/api/auth/refresh'];

/// Rutas de la cuenta, que no pertenecen a un negocio y no llevan `X-Business-Id`.
const accountPrefixes = ['/api/auth/', '/api/businesses', '/api/invitations', '/api/admin/'];

/// Pone el token y el negocio activo, renueva la sesión una vez ante un 401, bloquea toda
/// escritura sin conexión (RF-61) y convierte los fallos en [ApiError], [OfflineError] o
/// [SessionExpiredError] para que la interfaz los traduzca al español.
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const base = environment.apiUrl;
  if (!req.url.startsWith(`${base}/api/`)) return next(req);

  const session = inject(SessionService);
  const net = inject(ConnectivityService);
  const path = req.url.slice(base.length).split('?')[0];

  if (req.method !== 'GET' && !net.online()) return throwError(() => new OfflineError());

  const isAnonymous = anonymous.includes(path);
  const withAuth = (token: string | null): HttpRequest<unknown> => {
    if (isAnonymous) return req;
    const headers: Record<string, string> = {};
    if (token) headers['Authorization'] = `Bearer ${token}`;
    const business = session.activeBusinessId();
    if (business && !accountPrefixes.some((p) => path.startsWith(p))) {
      headers['X-Business-Id'] = business;
    }
    return req.clone({ setHeaders: headers });
  };

  const attempt = (token: string | null): Observable<never> =>
    next(withAuth(token)) as Observable<never>;

  return attempt(session.accessToken()).pipe(
    catchError((error: unknown) => {
      if (!isAnonymous && error instanceof HttpErrorResponse && error.status === 401) {
        return from(session.refresh()).pipe(
          switchMap((renewed) =>
            renewed
              ? attempt(session.accessToken()).pipe(
                  catchError((e) => {
                    const mapped = toError(e);
                    reactToStatus(session, mapped);
                    return throwError(() => mapped);
                  }),
                )
              : throwError(() => new SessionExpiredError()),
          ),
        );
      }
      const mapped = toError(error);
      if (!isAnonymous) reactToStatus(session, mapped);
      return throwError(() => mapped);
    }),
  );
};

/// Los avisos de negocio y de cuenta (T194, RF-98, RF-99, RF-103) cambian el estado de la sesión
/// al llegar, sin esperar a que la pantalla los pida.
function reactToStatus(session: SessionService, error: unknown): void {
  if (!(error instanceof ApiError)) return;
  if (error.code === 'business_pending') session.markBusinessStatus('pending');
  else if (error.code === 'business_suspended') session.markBusinessStatus('suspended');
  else if (error.code === 'account_suspended') {
    session.clear();
    session.notice.set(errorMessageForCode('account_suspended') ?? null);
  }
}

function toError(error: unknown): unknown {
  if (!(error instanceof HttpErrorResponse)) return error;
  if (error.status === 0) return new OfflineError();
  const body = error.error as { code?: string; codes?: string[] } | null;
  const code = typeof body?.code === 'string' ? body.code : 'unexpected';
  return new ApiError(error.status, code, body?.codes ?? [code]);
}
