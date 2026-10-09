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
    for (final id in ['b-1', 'b-2', 'b-3']) {
      await insertBusiness(db, id, name: 'Negocio $id');
    }
  });

  tearDown(() => db.close());

  group('sincronizar todos los negocios con pendientes (T201)', () {
    test(
      'envía la cola de cada negocio y solo de los que tienen pendientes',
      () async {
        await insertOutboxOp(db, 'op-1', 'b-1');
        await insertOutboxOp(db, 'op-2', 'b-2', entityId: 'c-2');

        final outcomes = await sync.syncAllPending();

        expect(outcomes.keys.toSet(), {'b-1', 'b-2'});
        expect(outcomes.values, everyElement(isA<SyncSucceeded>()));
        expect(await sync.pendingCount(), 0);
      },
    );

    test('si un negocio falla, los otros se intentan igual y la cola del que falló se conserva', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');
      await insertOutboxOp(db, 'op-2', 'b-2', entityId: 'c-2');
      api.pushResult = (op) {
        if (op.opId == 'op-1') {
          throw const NetworkException();
        }
        return null;
      };

      final outcomes = await sync.syncAllPending();

      expect(outcomes['b-1'], isA<SyncFailed>());
      expect(outcomes['b-2'], isA<SyncSucceeded>());
      expect(await sync.pendingCount(), 1);
    });

    test('sin pendientes no llama al servidor', () async {
      final outcomes = await sync.syncAllPending();

      expect(outcomes, isEmpty);
      expect(api.calls, isEmpty);
    });
  });
}
