import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/ledger_queries.dart';
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
    sync = SyncService(sessions: sessions, api: api, db: db);
    await sessions.login('ana@correo.com', 'contrasena1');
    api.calls.clear();
    // Lo único que un dispositivo nuevo sabe del negocio antes de sincronizar.
    await insertBusiness(db, 'b-1');
  });

  tearDown(() => db.close());

  group('descarga inicial en un dispositivo nuevo (RF-58)', () {
    test(
      'un dispositivo vacío queda con los mismos datos del negocio',
      () async {
        api.pageSize = 3;
        api.serverChanges.addAll([
          // El fiado llega antes que su cliente (que se editó después): la
          // página no debe depender del orden.
          fiadoChange(1, 'f-1', 'c-1', total: 1400),
          productChange(2, 'p-1'),
          paymentChange(3, 'a-1', 'c-1', amount: 500),
          fiadoChange(4, 'f-2', 'c-2', total: 3000),
          clientChange(5, 'c-1', name: 'Ana', version: 2),
          clientChange(6, 'c-2', name: 'Beto'),
          paymentChange(
            7,
            'a-2',
            'c-2',
            amount: 3000,
            annulledAt: DateTime.utc(2026, 10, 9, 17),
          ),
        ]);

        final report = await sync.sync('b-1');

        expect(report.pull.received, 7);
        expect(api.pulledFrom, [0, 3, 6]);
        expect((await db.select(db.clients).get()).map((c) => c.name).toSet(), {
          'Ana',
          'Beto',
        });
        expect(await db.select(db.products).get(), hasLength(1));
        expect(await db.select(db.fiados).get(), hasLength(2));
        expect(await db.select(db.fiadoItems).get(), hasLength(2));
        expect(await db.select(db.payments).get(), hasLength(2));
        // Los saldos salen de los movimientos: el abono anulado no cuenta.
        final balances = await LedgerQueries(db).balancesByClient('b-1');
        expect(balances['c-1']!.amount.minorUnits, 900);
        expect(balances['c-2']!.amount.minorUnits, 3000);
        expect((await db.select(db.syncStates).getSingle()).cursor, 7);
      },
    );

    test(
      'un negocio sin datos termina sin error y con el cursor en cero',
      () async {
        final report = await sync.sync('b-1');

        expect(report.pull.received, 0);
        expect(await db.select(db.clients).get(), isEmpty);
        expect((await db.select(db.syncStates).getSingle()).cursor, 0);
      },
    );

    test(
      'antes de recibir, envía lo pendiente (primero push, luego pull)',
      () async {
        await insertOutboxOp(db, 'op-1', 'b-1');

        await sync.sync('b-1');

        expect(api.calls, ['push', 'pull']);
      },
    );

    test('sin pendientes solo pide cambios', () async {
      await sync.sync('b-1');

      expect(api.calls, ['pull']);
    });

    test('un fallo al enviar no sigue con la recepción', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');
      api.failures['push'] = const NetworkException();

      await expectLater(sync.sync('b-1'), throwsA(isA<NetworkException>()));

      expect(api.calls, ['push']);
    });
  });
}
