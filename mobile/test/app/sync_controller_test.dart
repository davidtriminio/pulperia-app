import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/app/sync_controller.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/data/sync/sync_service.dart';

import '../support/db_fixtures.dart';
import '../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;
  late MemorySessionStore store;

  setUp(() async {
    db = openDb();
    api = FakeApi();
    store = MemorySessionStore(
      StoredSession(
        userId: 'u-1',
        email: 'ana@correo.com',
        tokens: tokensAt(api.now),
        activeBusiness: remoteBusiness('b-1'),
      ),
    );
    await insertBusiness(db, 'b-1');
  });

  tearDown(() => db.close());

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        pulperiaApiProvider.overrideWithValue(api),
        syncWaitProvider.overrideWithValue((_) async {}),
        sessionStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => api.now),
      ],
    );
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);
    return c;
  }

  group('disparadores (RF-52)', () {
    test('cada petición inicia exactamente una sincronización', () async {
      final c = await container();

      for (final trigger in SyncTrigger.values) {
        api.calls.clear();
        await c.read(syncControllerProvider.notifier).request(trigger);
        expect(api.count('pull'), 1, reason: '$trigger');
      }
    });

    test('dos peticiones a la vez comparten una sola vuelta', () async {
      final c = await container();
      final sync = c.read(syncControllerProvider.notifier);

      await Future.wait([
        sync.request(SyncTrigger.open),
        sync.request(SyncTrigger.reconnect),
      ]);

      expect(api.count('pull'), 1);
    });

    test('sin negocio elegido no hace nada', () async {
      store.session = StoredSession(
        userId: 'u-1',
        email: 'ana@correo.com',
        tokens: tokensAt(api.now),
      );
      final c = await container();

      await c.read(syncControllerProvider.notifier).request(SyncTrigger.open);

      expect(api.calls, isEmpty);
    });

    test(
      'mientras trabaja el estado lo indica y al terminar guarda el resultado',
      () async {
        final c = await container();
        final seen = <bool>[];
        c.listen(syncControllerProvider, (_, s) => seen.add(s.running));

        await c
            .read(syncControllerProvider.notifier)
            .request(SyncTrigger.manual);

        expect(seen, [true, false]);
        expect(c.read(syncControllerProvider).last, isA<SyncSucceeded>());
      },
    );
  });

  group('refresco de la interfaz', () {
    test('si llegaron cambios sube la revisión de los datos locales', () async {
      final c = await container();
      final before = c.read(localDataRevisionProvider);
      api.serverChanges.add(clientChange(1, 'c-1'));

      await c.read(syncControllerProvider.notifier).request(SyncTrigger.open);

      expect(c.read(localDataRevisionProvider), before + 1);
    });

    test('si no cambió nada no la toca', () async {
      final c = await container();
      final before = c.read(localDataRevisionProvider);

      await c.read(syncControllerProvider.notifier).request(SyncTrigger.open);

      expect(c.read(localDataRevisionProvider), before);
    });
  });
}
