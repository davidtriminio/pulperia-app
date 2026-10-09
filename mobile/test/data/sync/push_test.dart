import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
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
  late SyncService sync;

  setUp(() async {
    db = openDb();
    api = FakeApi();
    store = MemorySessionStore();
    final sessions = SessionService(api: api, store: store, now: () => api.now);
    sync = SyncService(sessions: sessions, api: api, db: db);
    await sessions.login('ana@correo.com', 'contrasena1');
    api.calls.clear();
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2', name: 'Abarrotes Beto');
  });

  tearDown(() => db.close());

  Future<List<OutboxOp>> queue() => (db.select(
    db.outboxOps,
  )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

  group('envío de la cola (RF-52, RF-53, RF-56)', () {
    test('sin operaciones pendientes no llama al servidor', () async {
      final report = await sync.pushPending('b-1');

      expect(api.count('push'), 0);
      expect(report.sent, 0);
    });

    test(
      'envía las pendientes en orden de creación con todos sus datos',
      () async {
        await insertOutboxOp(
          db,
          'op-1',
          'b-1',
          type: 'client.create',
          entityId: 'c-1',
          payload: '{"name":"Ana"}',
          createdAt: DateTime.utc(2026, 10, 9, 10),
        );
        await insertOutboxOp(
          db,
          'op-2',
          'b-1',
          type: 'client.update',
          entityId: 'c-1',
          payload: '{"name":"Ana López"}',
          baseVersion: 1,
          createdAt: DateTime.utc(2026, 10, 9, 9),
        );

        await sync.pushPending('b-1');

        final sent = api.pushed.single;
        // El orden es el de creación local, no el de la fecha del dispositivo.
        expect(sent.map((o) => o.opId), ['op-1', 'op-2']);
        expect(sent[1].type, 'client.update');
        expect(sent[1].entityId, 'c-1');
        expect(sent[1].payload, {'name': 'Ana López'});
        expect(sent[1].baseVersion, 1);
        expect(sent[1].createdAt, DateTime.utc(2026, 10, 9, 9));
      },
    );

    test('las aplicadas y las duplicadas salen de la cola', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');
      await insertOutboxOp(db, 'op-2', 'b-1', entityId: 'c-2');
      api.pushResult = (op) => OperationResult(
        opId: op.opId,
        status: op.opId == 'op-1'
            ? OperationStatus.applied
            : OperationStatus.duplicate,
      );

      final report = await sync.pushPending('b-1');

      expect(await queue(), isEmpty);
      expect(report.sent, 2);
      expect(report.rejected, 0);
    });

    test('una rechazada queda visible con su código y no se reenvía', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');
      await insertOutboxOp(db, 'op-2', 'b-1', entityId: 'c-2');
      api.pushResult = (op) => op.opId == 'op-1'
          ? OperationResult(
              opId: op.opId,
              status: OperationStatus.rejected,
              code: 'client_not_found',
              codes: const ['client_not_found'],
            )
          : null;

      final report = await sync.pushPending('b-1');

      final rows = await queue();
      expect(rows.map((o) => (o.opId, o.status, o.errorCode)), [
        ('op-1', 'rejected', 'client_not_found'),
      ]);
      expect(report.sent, 1);
      expect(report.rejected, 1);

      // Una segunda vuelta no vuelve a mandar la rechazada.
      api.calls.clear();
      await sync.pushPending('b-1');
      expect(api.count('push'), 0);
    });

    test('solo envía las operaciones del negocio pedido', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');
      await insertOutboxOp(db, 'op-2', 'b-2', entityId: 'c-2');

      await sync.pushPending('b-1');

      expect(api.pushed.single.map((o) => o.opId), ['op-1']);
      expect((await queue()).map((o) => o.opId), ['op-2']);
    });

    test('un lote grande se parte en tandas del tope del servidor', () async {
      for (var i = 0; i < SyncService.maxBatch + 3; i++) {
        await insertOutboxOp(db, 'op-$i', 'b-1', entityId: 'c-$i');
      }

      final report = await sync.pushPending('b-1');

      expect(api.pushed.map((b) => b.length), [SyncService.maxBatch, 3]);
      expect(report.sent, SyncService.maxBatch + 3);
      expect(await queue(), isEmpty);
    });

    test('una operación sin resultado sigue pendiente', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');
      api.pushResult = (op) =>
          OperationResult(opId: 'otra', status: OperationStatus.applied);

      final report = await sync.pushPending('b-1');

      expect((await queue()).map((o) => o.status), ['pending']);
      expect(report.sent, 0);
    });
  });

  group('cambios sin enviar', () {
    test(
      'cuenta las pendientes de todos los negocios, no las rechazadas',
      () async {
        await insertOutboxOp(db, 'op-1', 'b-1');
        await insertOutboxOp(db, 'op-2', 'b-2', entityId: 'c-2');
        await insertOutboxOp(
          db,
          'op-3',
          'b-1',
          entityId: 'c-3',
          status: 'rejected',
          errorCode: 'client_not_found',
        );

        expect(await sync.pendingCount(), 2);
        expect(await sync.pendingCount(businessId: 'b-1'), 1);
      },
    );
  });
}
