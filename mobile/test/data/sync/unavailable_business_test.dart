import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/data/sync/sync_service.dart';
import 'package:pulperia_mobile/domain/business/business_status.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

/// T194: un negocio pendiente o suspendido rechaza la sincronización con su código; el teléfono
/// conserva lo que tiene y su cola (RF-98, RF-102, D-29, D-30).
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
    await insertBusiness(db, 'b-1');
    await insertClient(db, 'c-1', 'b-1');
    await insertOutboxOp(db, 'op-1', 'b-1');
    api.calls.clear();
  });

  tearDown(() => db.close());

  for (final (code, reason) in [
    ('business_pending', SyncFailure.businessPending),
    ('business_suspended', SyncFailure.businessSuspended),
  ]) {
    group(code, () {
      test('al enviar: se informa el motivo y la cola queda intacta', () async {
        api.failures['push'] = ApiException(403, code, [code]);

        final outcome = await sync.attempt('b-1');

        expect(outcome, isA<SyncFailed>());
        final failed = outcome as SyncFailed;
        expect((failed.reason, failed.code), (reason, code));
        expect(failed.retryable, isFalse);
        final queue = await db.select(db.outboxOps).get();
        expect(queue.map((o) => (o.opId, o.status)), [('op-1', 'pending')]);
      });

      test('al recibir: lo mismo, y no se borra nada del teléfono', () async {
        await db.delete(db.outboxOps).go();
        api.failures['pull'] = ApiException(403, code, [code]);

        final outcome = await sync.attempt('b-1');

        expect((outcome as SyncFailed).reason, reason);
        expect(await db.select(db.clients).get(), hasLength(1));
        expect(await db.select(db.businesses).get(), hasLength(1));
      });

      test(
        'no se trata como baja del negocio ni se comprueba la lista',
        () async {
          api.failures['pull'] = ApiException(403, code, [code]);
          await db.delete(db.outboxOps).go();
          api.calls.clear();

          await sync.attempt('b-1');

          expect(api.count('listBusinesses'), 0);
        },
      );

      test(
        'con syncWithRetries no se reintenta: no se arregla esperando',
        () async {
          api.failures['push'] = ApiException(403, code, [code]);

          await sync.syncWithRetries('b-1');

          expect(api.count('push'), 1);
        },
      );
    });
  }

  test(
    'un 403 forbidden corriente sigue siendo la comprobación de baja',
    () async {
      api.failures['push'] = const ApiException(403, 'forbidden', [
        'forbidden',
      ]);
      api.businesses = [remoteBusiness('b-1', status: BusinessStatus.active)];

      final outcome = await sync.attempt('b-1');

      expect((outcome as SyncFailed).reason, SyncFailure.refused);
      expect(api.count('listBusinesses'), 1);
    },
  );
}
