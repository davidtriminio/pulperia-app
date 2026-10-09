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
  late MemorySessionStore store;
  late SessionService sessions;
  late SyncService sync;
  late List<Duration> waits;

  setUp(() async {
    db = openDb();
    api = FakeApi();
    store = MemorySessionStore();
    sessions = SessionService(api: api, store: store, now: () => api.now);
    waits = [];
    sync = SyncService(
      sessions: sessions,
      api: api,
      db: db,
      wait: (d) async => waits.add(d),
    );
    await sessions.login('ana@correo.com', 'contrasena1');
    api.calls.clear();
    await insertBusiness(db, 'b-1');
    await insertOutboxOp(db, 'op-1', 'b-1');
  });

  tearDown(() => db.close());

  Future<int> pending() => sync.pendingCount();

  group('fallos de red o del servidor conservan la cola (RF-56)', () {
    test(
      'sin red: las operaciones siguen pendientes y se envían luego',
      () async {
        api.offline = true;

        final outcome = await sync.attempt('b-1');

        expect(outcome, isA<SyncFailed>());
        expect((outcome as SyncFailed).reason, SyncFailure.network);
        expect(outcome.retryable, isTrue);
        expect(await pending(), 1);

        api.offline = false;
        final later = await sync.attempt('b-1');

        expect(later, isA<SyncSucceeded>());
        expect(await pending(), 0);
      },
    );

    test('un error del servidor (5xx) también es reintentable', () async {
      api.failures['push'] = const ApiException(503, 'unavailable');

      final outcome = await sync.attempt('b-1') as SyncFailed;

      expect(outcome.reason, SyncFailure.server);
      expect(outcome.retryable, isTrue);
      expect(await pending(), 1);
    });

    test(
      'una respuesta que no es el contrato es un fallo del servidor',
      () async {
        api.failures['pull'] = const ApiException(
          200,
          ApiException.invalidResponse,
        );
        await db.delete(db.outboxOps).go();

        final outcome = await sync.attempt('b-1') as SyncFailed;

        expect(outcome.reason, SyncFailure.server);
      },
    );

    test('que el servidor rechace la petición no se reintenta solo', () async {
      api.failures['push'] = const ApiException(403, 'not_allowed');

      final outcome = await sync.attempt('b-1') as SyncFailed;

      expect(outcome.reason, SyncFailure.refused);
      expect(outcome.code, 'not_allowed');
      expect(outcome.retryable, isFalse);
      expect(await pending(), 1);
    });

    test(
      'sin sesión utilizable se pide iniciar sesión, sin perder la cola',
      () async {
        await store.clear();

        final outcome = await sync.attempt('b-1') as SyncFailed;

        expect(outcome.reason, SyncFailure.sessionExpired);
        expect(outcome.retryable, isFalse);
        expect(await pending(), 1);
        expect(api.calls, isEmpty);
      },
    );

    test(
      'si falla la tanda 2, la 1 ya quedó resuelta y el resto sigue pendiente',
      () async {
        await db.delete(db.outboxOps).go();
        for (var i = 0; i < SyncService.maxBatch + 3; i++) {
          await insertOutboxOp(db, 'op-$i', 'b-1', entityId: 'c-$i');
        }
        api.pushResult = (op) {
          if (op.opId == 'op-${SyncService.maxBatch}') {
            throw const NetworkException('se cayó');
          }
          return null;
        };

        final outcome = await sync.attempt('b-1');

        expect(outcome, isA<SyncFailed>());
        expect(await pending(), 3);

        api.pushResult = null;
        await sync.attempt('b-1');
        expect(await pending(), 0);
      },
    );
  });

  group('reintentos', () {
    test('reintenta con espera creciente hasta lograrlo', () async {
      var failures = 2;
      api.pushResult = (op) {
        if (failures > 0) {
          failures--;
          throw const NetworkException();
        }
        return null;
      };

      final outcome = await sync.syncWithRetries('b-1');

      expect(outcome, isA<SyncSucceeded>());
      expect(waits, SyncService.retryDelays.take(2).toList());
      expect(api.count('push'), 3);
      expect(await pending(), 0);
    });

    test('se rinde tras agotar los intentos y deja la cola intacta', () async {
      api.offline = true;

      final outcome = await sync.syncWithRetries('b-1');

      expect(outcome, isA<SyncFailed>());
      expect(waits, SyncService.retryDelays);
      expect(api.count('push'), SyncService.retryDelays.length + 1);
      expect(await pending(), 1);
    });

    test('lo que no se arregla reintentando no se reintenta', () async {
      api.failures['push'] = const ApiException(403, 'not_allowed');

      await sync.syncWithRetries('b-1');

      expect(waits, isEmpty);
      expect(api.count('push'), 1);
    });
  });

  group('una sincronización a la vez', () {
    test('dos peticiones simultáneas comparten la misma vuelta', () async {
      final a = sync.attempt('b-1');
      final b = sync.attempt('b-1');

      final results = await Future.wait([a, b]);

      expect(identical(results[0], results[1]), isTrue);
      expect(api.count('push'), 1);
      expect(api.count('pull'), 1);
    });

    test('terminada una, la siguiente empieza de nuevo', () async {
      await sync.attempt('b-1');
      await sync.attempt('b-1');

      expect(api.count('pull'), 2);
    });
  });
}
