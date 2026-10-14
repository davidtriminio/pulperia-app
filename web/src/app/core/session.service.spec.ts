import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { environment } from '../../environments/environment';
import { ApiError, OfflineError, SessionExpiredError } from './api-error';
import { apiInterceptor } from './api.interceptor';
import { ConnectivityService } from './connectivity.service';
import { SessionService } from './session.service';

const api = environment.apiUrl;
const tokens = {
  userId: 'u1',
  accessToken: 'access-1',
  accessExpiresAt: '2026-10-09T15:15:00Z',
  refreshToken: 'refresh-1',
  refreshExpiresAt: '2027-01-07T15:00:00Z',
};
const tick = () => new Promise<void>((resolve) => setTimeout(resolve));
const unauthorized = { status: 401, statusText: 'Unauthorized' };

function configure(): void {
  TestBed.configureTestingModule({
    providers: [provideHttpClient(withInterceptors([apiInterceptor])), provideHttpClientTesting()],
  });
}

describe('sesión e interceptor', () => {
  let httpTesting: HttpTestingController;
  let http: HttpClient;
  let session: SessionService;
  let net: ConnectivityService;

  beforeEach(() => {
    sessionStorage.clear();
    configure();
    httpTesting = TestBed.inject(HttpTestingController);
    http = TestBed.inject(HttpClient);
    session = TestBed.inject(SessionService);
    net = TestBed.inject(ConnectivityService);
  });

  afterEach(() => httpTesting.verify());

  async function signIn(): Promise<void> {
    const done = session.login('ana@correo.com', 'contrasena1');
    httpTesting.expectOne(`${api}/api/auth/login`).flush(tokens);
    await done;
  }

  it('inicia sesión y guarda los tokens en sessionStorage', async () => {
    const done = session.login('ana@correo.com', 'contrasena1');
    const req = httpTesting.expectOne(`${api}/api/auth/login`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ email: 'ana@correo.com', password: 'contrasena1' });
    expect(req.request.headers.has('Authorization')).toBe(false);
    req.flush(tokens);
    await done;

    expect(session.isSignedIn()).toBe(true);
    expect(session.email()).toBe('ana@correo.com');
    expect(sessionStorage.getItem('pulperia.session')).toContain('access-1');
  });

  it('envía el token y el negocio activo en las consultas del negocio', async () => {
    await signIn();
    session.selectBusiness('b1');

    http.get(`${api}/api/clients`).subscribe();
    const req = httpTesting.expectOne(`${api}/api/clients`);
    expect(req.request.headers.get('Authorization')).toBe('Bearer access-1');
    expect(req.request.headers.get('X-Business-Id')).toBe('b1');
    req.flush([]);
  });

  it('no manda X-Business-Id a las rutas de cuenta', async () => {
    await signIn();
    session.selectBusiness('b1');

    http.get(`${api}/api/businesses`).subscribe();
    const req = httpTesting.expectOne(`${api}/api/businesses`);
    expect(req.request.headers.get('Authorization')).toBe('Bearer access-1');
    expect(req.request.headers.has('X-Business-Id')).toBe(false);
    req.flush([]);
  });

  it('renueva la sesión una vez ante un 401 y repite la petición', async () => {
    await signIn();
    session.selectBusiness('b1');

    let result: unknown;
    http.get(`${api}/api/clients`).subscribe((r) => (result = r));
    httpTesting
      .expectOne(`${api}/api/clients`)
      .flush({ code: 'unauthorized', codes: ['unauthorized'] }, unauthorized);
    const refresh = httpTesting.expectOne(`${api}/api/auth/refresh`);
    expect(refresh.request.body).toEqual({ refreshToken: 'refresh-1' });
    refresh.flush({ ...tokens, accessToken: 'access-2', refreshToken: 'refresh-2' });
    await tick();
    const retry = httpTesting.expectOne(`${api}/api/clients`);
    expect(retry.request.headers.get('Authorization')).toBe('Bearer access-2');
    retry.flush(['ok']);

    expect(result).toEqual(['ok']);
  });

  it('cierra la sesión si no se puede renovar', async () => {
    await signIn();

    let error: unknown;
    http.get(`${api}/api/clients`).subscribe({ error: (e) => (error = e) });
    httpTesting.expectOne(`${api}/api/clients`).flush({}, unauthorized);
    httpTesting
      .expectOne(`${api}/api/auth/refresh`)
      .flush({ code: 'invalid_refresh_token', codes: ['invalid_refresh_token'] }, unauthorized);

    await tick();
    expect(error).toBeInstanceOf(SessionExpiredError);
    expect(session.isSignedIn()).toBe(false);
    expect(sessionStorage.getItem('pulperia.session')).toBeNull();
  });

  it('bloquea toda escritura sin conexión, con aviso en español', async () => {
    await signIn();
    net.online.set(false);

    let error: unknown;
    http.post(`${api}/api/operations`, {}).subscribe({ error: (e) => (error = e) });

    httpTesting.expectNone(`${api}/api/operations`);
    expect(error).toBeInstanceOf(OfflineError);
  });

  it('convierte un fallo de red y un error de la API en errores propios', async () => {
    await signIn();

    let offline: unknown;
    http.get(`${api}/api/summary`).subscribe({ error: (e) => (offline = e) });
    httpTesting.expectOne(`${api}/api/summary`).error(new ProgressEvent('error'));
    expect(offline).toBeInstanceOf(OfflineError);

    let rejected: unknown;
    http.get(`${api}/api/summary`).subscribe({ error: (e) => (rejected = e) });
    httpTesting
      .expectOne(`${api}/api/summary`)
      .flush(
        { code: 'business_suspended', codes: ['business_suspended'] },
        { status: 403, statusText: 'Forbidden' },
      );
    expect(rejected).toBeInstanceOf(ApiError);
    expect((rejected as ApiError).code).toBe('business_suspended');
  });

  it('cierra la sesión: avisa al servidor y borra lo guardado', async () => {
    await signIn();

    const done = session.logout();
    const req = httpTesting.expectOne(`${api}/api/auth/logout`);
    expect(req.request.headers.get('Authorization')).toBe('Bearer access-1');
    req.flush(null);
    await done;

    expect(session.isSignedIn()).toBe(false);
    expect(sessionStorage.getItem('pulperia.session')).toBeNull();
  });
});

describe('sesión guardada', () => {
  it('se restaura al crearse el servicio', () => {
    sessionStorage.setItem(
      'pulperia.session',
      JSON.stringify({ tokens, email: 'ana@correo.com', activeBusinessId: 'b1' }),
    );
    configure();
    const restored = TestBed.inject(SessionService);

    expect(restored.isSignedIn()).toBe(true);
    expect(restored.activeBusinessId()).toBe('b1');
    sessionStorage.clear();
  });
});
