import 'package:drift/drift.dart' show GeneratedColumn, TableInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/data/sync/sync_service.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;
  late SyncService sync;

  setUp(() async {
    db = openDb();
    api = FakeApi();
    final sessions = SessionService(
      api: api,
      store: MemorySessionStore(),
      now: () => api.now,
    );
    sync = SyncService(
      sessions: sessions,
      api: api,
      db: db,
      wait: (_) async {},
    );
    await sessions.login('ana@correo.com', 'contrasena1');
    api.calls.clear();
    for (final id in ['b-1', 'b-2']) {
      await insertBusiness(db, id, name: 'Negocio $id');
      await db
          .into(db.memberships)
          .insert(
            MembershipsCompanion.insert(
              userId: 'u-1',
              businessId: id,
              role: 'employee',
            ),
          );
      await insertClient(db, 'c-$id', id);
      await insertProduct(db, 'p-$id', id);
      await insertFiado(db, 'f-$id', id, 'c-$id');
      await insertFiadoItem(db, 'i-$id', id, 'f-$id', productId: 'p-$id');
      await insertPayment(db, 'a-$id', id, 'c-$id');
      await db
          .into(db.syncStates)
          .insert(SyncStatesCompanion.insert(businessId: id));
    }
    await insertOutboxOp(db, 'op-b1', 'b-1', entityId: 'c-b-1');
    await insertOutboxOp(db, 'op-b2', 'b-2', entityId: 'c-b-2');
  });

  tearDown(() => db.close());

  Future<Map<String, int>> counts(String businessId) async {
    Future<int> n(TableInfo table, GeneratedColumn<String> column) async =>
        (await (db.select(
          table,
        )..where((_) => column.equals(businessId))).get()).length;
    return {
      'clients': await n(db.clients, db.clients.businessId),
      'products': await n(db.products, db.products.businessId),
      'fiados': await n(db.fiados, db.fiados.businessId),
      'items': await n(db.fiadoItems, db.fiadoItems.businessId),
      'payments': await n(db.payments, db.payments.businessId),
      'outbox': await n(db.outboxOps, db.outboxOps.businessId),
      'sync': await n(db.syncStates, db.syncStates.businessId),
      'memberships': await n(db.memberships, db.memberships.businessId),
      'businesses': (await (db.select(
        db.businesses,
      )..where((b) => b.id.equals(businessId))).get()).length,
    };
  }

  const gone = {
    'clients': 0,
    'products': 0,
    'fiados': 0,
    'items': 0,
    'payments': 0,
    'outbox': 0,
    'sync': 0,
    'memberships': 0,
    'businesses': 0,
  };

  group('baja del negocio (RF-11, RF-12)', () {
    test(
      'borrar sus datos no deja nada de ese negocio y respeta los demás',
      () async {
        await sync.purgeBusiness('b-1');

        expect(await counts('b-1'), gone);
        expect((await counts('b-2')).values, everyElement(1));
      },
    );

    test('si el servidor ya no te deja entrar y el negocio no está en tu lista, se borra', () async {
      api.failures['pull'] = const ApiException(403, 'forbidden');
      api.businesses = [remoteBusiness('b-2')];

      final outcome = await sync.attempt('b-1') as SyncFailed;

      expect(outcome.reason, SyncFailure.removed);
      expect(outcome.retryable, isFalse);
      expect(await counts('b-1'), gone);
      expect((await counts('b-2')).values, everyElement(1));
    });

    test('el último lote se envía antes de borrar', () async {
      api.failures['pull'] = const ApiException(403, 'forbidden');
      api.businesses = [];

      await sync.attempt('b-1');

      expect(api.pushed.single.map((o) => o.opId), ['op-b1']);
      expect((await counts('b-1'))['clients'], 0);
    });

    test('un 403 con el negocio aún en tu lista no borra nada', () async {
      api.failures['push'] = const ApiException(403, 'forbidden');
      api.businesses = [remoteBusiness('b-1'), remoteBusiness('b-2')];

      final outcome = await sync.attempt('b-1') as SyncFailed;

      expect(outcome.reason, SyncFailure.refused);
      expect((await counts('b-1')).values, everyElement(1));
    });

    test(
      'sin poder confirmarlo con el servidor no se borra y se reintenta',
      () async {
        api.failures['pull'] = const ApiException(403, 'forbidden');
        api.failures['listBusinesses'] = const NetworkException();

        final outcome = await sync.attempt('b-1') as SyncFailed;

        expect(outcome.reason, SyncFailure.network);
        // La cola sí salió: el último lote se envió antes de preguntar.
        expect(await counts('b-1'), {
          'clients': 1,
          'products': 1,
          'fiados': 1,
          'items': 1,
          'payments': 1,
          'outbox': 0,
          'sync': 1,
          'memberships': 1,
          'businesses': 1,
        });
      },
    );
  });
}
