import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { environment } from '../../environments/environment';
import { apiInterceptor } from '../core/api.interceptor';
import { SessionService } from '../core/session.service';
import { BusinessChooserPage } from '../business/business-chooser.page';
import { LoginPage } from './login.page';
import { RegisterPage } from './register.page';

const api = environment.apiUrl;
const tokens = {
  userId: 'u1',
  accessToken: 'a1',
  accessExpiresAt: '2026-10-09T15:15:00Z',
  refreshToken: 'r1',
  refreshExpiresAt: '2027-01-07T15:00:00Z',
};
const ana = {
  id: 'b1',
  name: 'Pulpería Ana',
  role: 'owner',
  amountMode: 'integer',
  quantityMode: 'integer',
  status: 'active',
};
const beto = { ...ana, id: 'b2', name: 'Abarrotes Beto', role: 'employee' };

const tick = () => new Promise<void>((resolve) => setTimeout(resolve));

function setup() {
  sessionStorage.clear();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([]),
      provideHttpClient(withInterceptors([apiInterceptor])),
      provideHttpClientTesting(),
    ],
  });
  const router = TestBed.inject(Router);
  const navigate = vi.spyOn(router, 'navigateByUrl').mockResolvedValue(true);
  return { http: TestBed.inject(HttpTestingController), navigate };
}

function type(root: HTMLElement, selector: string, value: string): void {
  const input = root.querySelector<HTMLInputElement>(selector)!;
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

function click(root: HTMLElement, selector: string): void {
  root.querySelector<HTMLElement>(selector)!.click();
}

describe('LoginPage', () => {
  it('avisa por campo y no llama al servidor si faltan datos', async () => {
    const { http } = setup();
    const fixture = TestBed.createComponent(LoginPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;

    click(root, '[data-test=submit]');
    fixture.detectChanges();

    expect(root.textContent).toContain('Escribe tu correo');
    expect(root.textContent).toContain('Escribe tu contraseña');
    http.expectNone(`${api}/api/auth/login`);
  });

  it('con un solo negocio entra directo a él', async () => {
    const { http, navigate } = setup();
    const fixture = TestBed.createComponent(LoginPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    type(root, '[data-test=email]', 'ana@correo.com');
    type(root, '[data-test=password]', 'contrasena1');

    click(root, '[data-test=submit]');
    http.expectOne(`${api}/api/auth/login`).flush(tokens);
    await tick();
    http.expectOne(`${api}/api/businesses`).flush([ana]);
    await tick();

    const session = TestBed.inject(SessionService);
    expect(session.activeBusinessId()).toBe('b1');
    expect(navigate).toHaveBeenCalledWith('/');
  });

  it('con varios negocios pide elegir', async () => {
    const { http, navigate } = setup();
    const fixture = TestBed.createComponent(LoginPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    type(root, '[data-test=email]', 'ana@correo.com');
    type(root, '[data-test=password]', 'contrasena1');

    click(root, '[data-test=submit]');
    http.expectOne(`${api}/api/auth/login`).flush(tokens);
    await tick();
    http.expectOne(`${api}/api/businesses`).flush([ana, beto]);
    await tick();

    expect(TestBed.inject(SessionService).activeBusinessId()).toBeNull();
    expect(navigate).toHaveBeenCalledWith('/negocios');
  });

  it('muestra en español el error de credenciales y el de cuenta suspendida', async () => {
    const { http } = setup();
    const fixture = TestBed.createComponent(LoginPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    type(root, '[data-test=email]', 'ana@correo.com');
    type(root, '[data-test=password]', 'contrasena1');

    click(root, '[data-test=submit]');
    http
      .expectOne(`${api}/api/auth/login`)
      .flush(
        { code: 'invalid_credentials', codes: ['invalid_credentials'] },
        { status: 401, statusText: 'Unauthorized' },
      );
    await tick();
    fixture.detectChanges();
    expect(root.querySelector('[role=alert]')?.textContent).toContain(
      'Correo o contraseña incorrectos',
    );

    click(root, '[data-test=submit]');
    http
      .expectOne(`${api}/api/auth/login`)
      .flush(
        { code: 'account_suspended', codes: ['account_suspended'] },
        { status: 403, statusText: 'Forbidden' },
      );
    await tick();
    fixture.detectChanges();
    expect(root.querySelector('[role=alert]')?.textContent).toContain('cuenta está suspendida');
  });
});

describe('RegisterPage', () => {
  it('exige nombre de negocio y los dos modos antes de llamar al servidor', async () => {
    const { http } = setup();
    const fixture = TestBed.createComponent(RegisterPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    type(root, '[data-test=email]', 'ana@correo.com');
    type(root, '[data-test=password]', 'contrasena1');

    click(root, '[data-test=submit]');
    fixture.detectChanges();

    expect(root.textContent).toContain('El nombre del negocio es obligatorio');
    expect(root.textContent).toContain('Elige cómo manejas los montos');
    expect(root.textContent).toContain('Elige cómo manejas las cantidades');
    http.expectNone(`${api}/api/auth/register`);
  });

  it('crea la cuenta con su negocio, inicia sesión y entra al negocio', async () => {
    const { http, navigate } = setup();
    const fixture = TestBed.createComponent(RegisterPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    type(root, '[data-test=email]', ' ana@correo.com ');
    type(root, '[data-test=password]', 'contrasena1');
    type(root, '[data-test=business]', ' Pulpería Ana ');
    click(root, '[data-test=amount-two_decimals]');
    click(root, '[data-test=quantity-integer]');

    click(root, '[data-test=submit]');
    const register = http.expectOne(`${api}/api/auth/register`);
    expect(register.request.body).toEqual({
      email: 'ana@correo.com',
      password: 'contrasena1',
      businessName: 'Pulpería Ana',
      amountMode: 'two_decimals',
      quantityMode: 'integer',
    });
    register.flush({ userId: 'u1', businessId: 'b1' });
    await tick();
    http.expectOne(`${api}/api/auth/login`).flush(tokens);
    await tick();
    http.expectOne(`${api}/api/businesses`).flush([{ ...ana, status: 'pending' }]);
    await tick();

    expect(navigate).toHaveBeenCalledWith('/');
  });

  it('muestra el correo repetido en español', async () => {
    const { http } = setup();
    const fixture = TestBed.createComponent(RegisterPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    type(root, '[data-test=email]', 'ana@correo.com');
    type(root, '[data-test=password]', 'contrasena1');
    type(root, '[data-test=business]', 'Pulpería Ana');
    click(root, '[data-test=amount-integer]');
    click(root, '[data-test=quantity-integer]');

    click(root, '[data-test=submit]');
    http
      .expectOne(`${api}/api/auth/register`)
      .flush({ code: 'email_taken', codes: ['email_taken'] }, { status: 409, statusText: 'Conflict' });
    await tick();
    fixture.detectChanges();

    expect(root.querySelector('[role=alert]')?.textContent).toContain(
      'Ya existe una cuenta con ese correo',
    );
  });
});

describe('BusinessChooserPage', () => {
  async function open(list: unknown[]) {
    const { http, navigate } = setup();
    sessionStorage.setItem(
      'pulperia.session',
      JSON.stringify({ tokens, email: 'ana@correo.com', activeBusinessId: null }),
    );
    const fixture = TestBed.createComponent(BusinessChooserPage);
    fixture.detectChanges();
    http.expectOne(`${api}/api/businesses`).flush(list);
    await tick();
    fixture.detectChanges();
    return { http, navigate, fixture, root: fixture.nativeElement as HTMLElement };
  }

  it('lista los negocios con su rol y al elegir uno lo activa', async () => {
    const { navigate, root } = await open([ana, beto]);

    expect(root.textContent).toContain('Pulpería Ana');
    expect(root.textContent).toContain('Dueño');
    expect(root.textContent).toContain('Abarrotes Beto');
    expect(root.textContent).toContain('Empleado');

    click(root, '[data-test=business-b2]');

    expect(TestBed.inject(SessionService).activeBusinessId()).toBe('b2');
    expect(navigate).toHaveBeenCalledWith('/');
  });

  it('sin negocios ofrece crear uno y valida el nombre', async () => {
    const { http, root, fixture } = await open([]);
    expect(root.textContent).toContain('Crear un negocio');

    click(root, '[data-test=create-submit]');
    fixture.detectChanges();
    expect(root.textContent).toContain('El nombre del negocio es obligatorio');
    http.expectNone(`${api}/api/businesses`);
  });

  it('crea un negocio nuevo y lo activa (RF-79)', async () => {
    const { http, navigate, root } = await open([ana]);
    type(root, '[data-test=create-name]', 'Abarrotes Cata');
    click(root, '[data-test=create-amount-integer]');
    click(root, '[data-test=create-quantity-fractional]');

    click(root, '[data-test=create-submit]');
    const req = http.expectOne((r) => r.method === 'POST' && r.url === `${api}/api/businesses`);
    expect(req.request.body).toEqual({
      name: 'Abarrotes Cata',
      amountMode: 'integer',
      quantityMode: 'fractional',
    });
    req.flush({ ...ana, id: 'b3', name: 'Abarrotes Cata', quantityMode: 'fractional' }, {
      status: 201,
      statusText: 'Created',
    });
    await tick();

    expect(TestBed.inject(SessionService).activeBusinessId()).toBe('b3');
    expect(navigate).toHaveBeenCalledWith('/');
  });
});
