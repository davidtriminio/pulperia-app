import { provideHttpClient, withInterceptors, HttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { environment } from '../../environments/environment';
import { LoginPage } from '../auth/login.page';
import { apiInterceptor } from '../core/api.interceptor';
import { SessionService } from '../core/session.service';
import { ShellComponent } from './shell.component';

const api = environment.apiUrl;
const tokens = {
  userId: 'u1',
  accessToken: 'a1',
  accessExpiresAt: '2026-10-09T15:15:00Z',
  refreshToken: 'r1',
  refreshExpiresAt: '2027-01-07T15:00:00Z',
};
const business = {
  id: 'b1',
  name: 'Pulpería Ana',
  role: 'owner',
  amountMode: 'integer',
  quantityMode: 'integer',
  status: 'active',
};
const tick = () => new Promise<void>((resolve) => setTimeout(resolve));

function setup(status: string) {
  sessionStorage.clear();
  sessionStorage.setItem(
    'pulperia.session',
    JSON.stringify({ tokens, email: 'ana@correo.com', activeBusinessId: 'b1' }),
  );
  TestBed.configureTestingModule({
    providers: [
      provideRouter([]),
      provideHttpClient(withInterceptors([apiInterceptor])),
      provideHttpClientTesting(),
    ],
  });
  const session = TestBed.inject(SessionService);
  session.businesses.set([{ ...business, status } as never]);
  return { session, http: TestBed.inject(HttpTestingController) };
}

describe('ShellComponent: negocio pendiente o suspendido (T194)', () => {
  it('con el negocio activo muestra el contenido', () => {
    setup('active');
    const fixture = TestBed.createComponent(ShellComponent);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;

    expect(root.querySelector('router-outlet')).not.toBeNull();
    expect(root.querySelector('[data-test=blocked]')).toBeNull();
  });

  it('con el negocio pendiente avisa y no muestra el contenido', () => {
    setup('pending');
    const fixture = TestBed.createComponent(ShellComponent);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;

    expect(root.textContent).toContain('Tu negocio está pendiente de activación');
    expect(root.textContent).toContain('Lo revisa quien administra la plataforma');
    expect(root.querySelector('router-outlet')).toBeNull();
  });

  it('«Comprobar ahora» avisa si sigue pendiente y libera el contenido al activarse', async () => {
    const { http } = setup('pending');
    const fixture = TestBed.createComponent(ShellComponent);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;

    root.querySelector<HTMLElement>('[data-test=check]')!.click();
    http.expectOne(`${api}/api/businesses`).flush([{ ...business, status: 'pending' }]);
    await tick();
    fixture.detectChanges();
    expect(root.textContent).toContain('Todavía no está activo. Inténtalo más tarde.');

    root.querySelector<HTMLElement>('[data-test=check]')!.click();
    http.expectOne(`${api}/api/businesses`).flush([business]);
    await tick();
    fixture.detectChanges();
    expect(root.querySelector('router-outlet')).not.toBeNull();
  });

  it('con el negocio suspendido muestra el aviso de suspensión', () => {
    setup('suspended');
    const fixture = TestBed.createComponent(ShellComponent);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;

    expect(root.textContent).toContain('Negocio suspendido');
    expect(root.textContent).toContain('Este negocio está suspendido');
    expect(root.querySelector('router-outlet')).toBeNull();
  });
});

describe('avisos que llegan con una petición (T194)', () => {
  it('un business_suspended marca el negocio como suspendido', async () => {
    const { session, http } = setup('active');
    const client = TestBed.inject(HttpClient);

    client.get(`${api}/api/clients`).subscribe({ error: () => undefined });
    http
      .expectOne(`${api}/api/clients`)
      .flush(
        { code: 'business_suspended', codes: ['business_suspended'] },
        { status: 403, statusText: 'Forbidden' },
      );
    await tick();

    expect(session.activeBusiness()?.status).toBe('suspended');
  });

  it('un business_pending marca el negocio como pendiente', async () => {
    const { session, http } = setup('active');

    TestBed.inject(HttpClient)
      .get(`${api}/api/summary`)
      .subscribe({ error: () => undefined });
    http
      .expectOne(`${api}/api/summary`)
      .flush(
        { code: 'business_pending', codes: ['business_pending'] },
        { status: 403, statusText: 'Forbidden' },
      );
    await tick();

    expect(session.activeBusiness()?.status).toBe('pending');
  });

  it('una cuenta suspendida cierra la sesión y deja el aviso para la pantalla de entrada', async () => {
    const { session, http } = setup('active');

    TestBed.inject(HttpClient)
      .get(`${api}/api/clients`)
      .subscribe({ error: () => undefined });
    http
      .expectOne(`${api}/api/clients`)
      .flush(
        { code: 'account_suspended', codes: ['account_suspended'] },
        { status: 403, statusText: 'Forbidden' },
      );
    await tick();

    expect(session.isSignedIn()).toBe(false);
    expect(session.notice()).toContain('Tu cuenta está suspendida');

    const fixture = TestBed.createComponent(LoginPage);
    fixture.detectChanges();
    expect((fixture.nativeElement as HTMLElement).querySelector('[role=alert]')?.textContent).toContain(
      'Tu cuenta está suspendida',
    );
  });
});
