import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import syncExamples from '../../../../shared/examples/sync.json';
import { environment } from '../../environments/environment';
import { ApiError } from './api-error';
import { apiInterceptor } from './api.interceptor';
import { errorMessage } from './error-messages';
import { IdGenerator } from './id-generator';
import { OperationsService } from './operations.service';
import { QueriesService } from './queries.service';

const api = environment.apiUrl;
const example = (name: string) =>
  syncExamples.cases.find((c) => c.name.startsWith(name))!.example as {
    opId: string;
    status: string;
    code?: string;
    codes?: string[];
  };

describe('IdGenerator', () => {
  it('genera UUID v7 únicos y ordenados por tiempo', () => {
    const generator = new IdGenerator();
    const a = generator.next();
    const b = generator.next();

    expect(a).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(a).not.toBe(b);
    expect(a.slice(0, 13) <= b.slice(0, 13)).toBe(true);
  });
});

describe('operaciones y consultas', () => {
  let httpTesting: HttpTestingController;
  let operations: OperationsService;
  let queries: QueriesService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([apiInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    httpTesting = TestBed.inject(HttpTestingController);
    operations = TestBed.inject(OperationsService);
    queries = TestBed.inject(QueriesService);
  });

  afterEach(() => httpTesting.verify());

  it('envía una operación con su opId y devuelve el resultado aplicado', async () => {
    const done = operations.send('client.archive', 'c1', {}, { baseVersion: 3 });
    const req = httpTesting.expectOne(`${api}/api/operations`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body.type).toBe('client.archive');
    expect(req.request.body.entityId).toBe('c1');
    expect(req.request.body.baseVersion).toBe(3);
    expect(req.request.body.opId).toMatch(/^[0-9a-f-]{36}$/);
    req.flush(example('operación aplicada'));

    expect((await done).status).toBe('applied');
  });

  it('acepta una operación repetida como correcta (idempotencia)', async () => {
    const done = operations.send('payment.create', 'p1', { amount: 100 });
    httpTesting.expectOne(`${api}/api/operations`).flush(example('operación repetida'));

    expect((await done).status).toBe('duplicate');
  });

  it('convierte el rechazo en un error con su código y su mensaje en español', async () => {
    const done = operations.send('client.update', 'c1', {}, { baseVersion: 1 });
    httpTesting.expectOne(`${api}/api/operations`).flush(example('operación rechazada con su código'));

    const error = await done.catch((e: unknown) => e);
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).code).toBe('version_conflict');
    expect(errorMessage(error)).toBe(
      'Otra persona modificó este registro antes y se conservó su versión.',
    );
  });

  it('pide clientes, archivados, detalle, productos y resumen al servidor', async () => {
    const clients = queries.clients();
    httpTesting.expectOne(`${api}/api/clients`).flush([]);
    expect(await clients).toEqual([]);

    const archived = queries.clients({ archived: true });
    httpTesting.expectOne(`${api}/api/clients?archived=true`).flush([]);
    await archived;

    const detail = queries.client('c1');
    httpTesting.expectOne(`${api}/api/clients/c1`).flush({ id: 'c1', movements: [] });
    expect((await detail).id).toBe('c1');

    const products = queries.products({ archived: true });
    httpTesting.expectOne(`${api}/api/products?archived=true`).flush([]);
    await products;

    const summary = queries.summary(5);
    httpTesting
      .expectOne(`${api}/api/summary?limit=5`)
      .flush({ debtTotal: 100, creditTotal: 0, debtors: [] });
    expect((await summary).debtTotal).toBe(100);
  });
});
