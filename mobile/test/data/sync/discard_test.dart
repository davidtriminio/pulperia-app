import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/data/sync/sync_service.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late SyncService sync;

  setUp(() async {
    db = openDb();
    final api = FakeApi();
    sync = SyncService(
      sessions: SessionService(
        api: api,
        store: MemorySessionStore(),
        now: () => api.now,
      ),
      api: api,
      db: db,
      wait: (_) async {},
    );
    await insertBusiness(db, 'b-1');
    await insertClient(db, 'c-1', 'b-1');
  });

  tearDown(() => db.close());

  Future<void> rejectedOp(String id, String type, String entityId) =>
      insertOutboxOp(
        db,
        id,
        'b-1',
        type: type,
        entityId: entityId,
        status: 'rejected',
        errorCode: 'client_not_found',
      );

  Future<int> opCount() async => (await db.select(db.outboxOps).get()).length;

  group('descartar un cambio no aplicado (T202)', () {
    test(
      'un fiado rechazado se borra del teléfono junto con sus ítems',
      () async {
        await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 5000);
        await insertFiadoItem(db, 'i-1', 'b-1', 'f-1');
        await rejectedOp('op-1', 'fiado.create', 'f-1');

        final done = await sync.discardRejected('op-1');

        expect(done, isTrue);
        expect(await db.select(db.fiados).get(), isEmpty);
        expect(await db.select(db.fiadoItems).get(), isEmpty);
        expect(await opCount(), 0);
      },
    );

    test('un abono rechazado se borra y deja de contar en el saldo', () async {
      await insertPayment(db, 'a-1', 'b-1', 'c-1');
      await rejectedOp('op-1', 'payment.create', 'a-1');

      await sync.discardRejected('op-1');

      expect(await db.select(db.payments).get(), isEmpty);
    });

    test(
      'una edición rechazada se descarta y se pide la versión del servidor',
      () async {
        await db
            .into(db.syncStates)
            .insert(
              SyncStatesCompanion.insert(
                businessId: 'b-1',
                cursor: const Value(42),
              ),
            );
        await rejectedOp('op-1', 'client.update', 'c-1');

        await sync.discardRejected('op-1');

        expect(await opCount(), 0);
        final state = await db.select(db.syncStates).getSingle();
        // Cursor en cero: la próxima vuelta vuelve a bajar los registros.
        expect(state.cursor, 0);
        // El cliente sigue ahí.
        expect(await db.select(db.clients).get(), hasLength(1));
      },
    );

    test(
      'un cliente creado y rechazado se borra si no tiene movimientos',
      () async {
        await insertClient(db, 'c-2', 'b-1', name: 'Nuevo');
        await rejectedOp('op-1', 'client.create', 'c-2');

        await sync.discardRejected('op-1');

        expect((await db.select(db.clients).get()).map((c) => c.id), ['c-1']);
      },
    );

    test(
      'un cliente con movimientos no se borra aunque su creación se descarte',
      () async {
        await insertFiado(db, 'f-1', 'b-1', 'c-1');
        await rejectedOp('op-1', 'client.create', 'c-1');

        await sync.discardRejected('op-1');

        expect(await db.select(db.clients).get(), hasLength(1));
        expect(await opCount(), 0);
      },
    );

    test('lo que está pendiente no se puede descartar', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');

      final done = await sync.discardRejected('op-1');

      expect(done, isFalse);
      expect(await opCount(), 1);
    });

    test('cuenta las rechazadas de un negocio', () async {
      await rejectedOp('op-1', 'client.update', 'c-1');
      await rejectedOp('op-2', 'client.archive', 'c-1');
      await insertOutboxOp(db, 'op-3', 'b-1', entityId: 'c-9');

      expect((await sync.rejectedOperations('b-1')).length, 2);
    });
  });
}
