import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, provideRouter, RouterStateSnapshot, UrlTree } from '@angular/router';
import { environment } from '../../environments/environment';
import { apiInterceptor } from './api.interceptor';
import { authGuard, businessGuard, guestGuard } from './guards';

const tokens = {
  userId: 'u1',
  accessToken: 'a1',
  accessExpiresAt: '2026-10-09T15:15:00Z',
  refreshToken: 'r1',
  refreshExpiresAt: '2027-01-07T15:00:00Z',
};
const tick = () => new Promise<void>((resolve) => setTimeout(resolve));

function run(guard: typeof authGuard) {
  return TestBed.runInInjectionContext(() =>
    guard({} as ActivatedRouteSnapshot, {} as RouterStateSnapshot),
  );
}

function signedIn(activeBusinessId: string | null): void {
  sessionStorage.setItem(
    'pulperia.session',
    JSON.stringify({ tokens, email: 'ana@correo.com', activeBusinessId }),
  );
}

describe('guards', () => {
  beforeEach(() => {
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        provideHttpClient(withInterceptors([apiInterceptor])),
        provideHttpClientTesting(),
      ],
    });
  });

  it('sin sesión manda a entrar y deja ver las pantallas de invitados', async () => {
    expect((run(authGuard) as UrlTree).toString()).toBe('/entrar');
    expect(run(guestGuard)).toBe(true);
    expect(((await run(businessGuard)) as UrlTree).toString()).toBe('/entrar');
  });

  it('con sesión, entrar y registrarse mandan a la raíz', () => {
    signedIn(null);

    expect(run(authGuard)).toBe(true);
    expect((run(guestGuard) as UrlTree).toString()).toBe('/');
  });

  it('sin negocio activo manda a elegir negocio', async () => {
    signedIn(null);

    expect(((await run(businessGuard)) as UrlTree).toString()).toBe('/negocios');
  });

  it('comprueba que el negocio activo siga siendo del usuario', async () => {
    signedIn('b1');
    const http = TestBed.inject(HttpTestingController);

    const allowed = run(businessGuard) as Promise<unknown>;
    http.expectOne(`${environment.apiUrl}/api/businesses`).flush([
      { id: 'b1', name: 'Ana', role: 'owner', amountMode: 'integer', quantityMode: 'integer', status: 'active' },
    ]);
    expect(await allowed).toBe(true);
  });

  it('si el negocio activo ya no está entre los del usuario, lo olvida y manda a elegir', async () => {
    signedIn('b9');
    const http = TestBed.inject(HttpTestingController);

    const result = run(businessGuard) as Promise<UrlTree>;
    http.expectOne(`${environment.apiUrl}/api/businesses`).flush([]);
    await tick();

    expect((await result).toString()).toBe('/negocios');
  });
});
