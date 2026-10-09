import 'package:drift/drift.dart' show Value;
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
    sync = SyncService(sessions: sessions, api: api, db: db);
    await sessions.login('ana@correo.com', 'contrasena1');
    await insertBusiness(db, 'b-1');
    // El cliente ya está sincronizado en la versión 1.
    api.serverChanges.add(clientChange(1, 'c-1', name: 'Ana', version: 1));
    await sync.sync('b-1');
    api.calls.clear();
    api.pulledFrom.clear();
  });

  tearDown(() => db.close());

  Future<void> localEdit(String name, {required int base}) async {
    await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
      ClientsCompanion(name: Value(name), version: Value(base + 1)),
    );
    await insertOutboxOp(
      db,
      'op-${base + 1}',
      'b-1',
      type: 'client.update',
      entityId: 'c-1',
      baseVersion: base,
    );
  }

  Future<Client> client() =>
      (db.select(db.clients)..where((c) => c.id.equals('c-1'))).getSingle();

  OperationResult conflict(PushOperation op) => OperationResult(
    opId: op.opId,
    status: OperationStatus.rejected,
    code: 'version_conflict',
    codes: const ['version_conflict'],
  );

  group('conflicto de versión (RF-55, D-8)', () {
    test(
      'la edición local se descarta y el registro queda como el del servidor',
      () async {
        await localEdit('Ana editada aquí', base: 1);
        // Otro teléfono editó primero: el servidor está en la versión 2.
        api.serverChanges.add(
          clientChange(5, 'c-1', name: 'Ana editada allá', version: 2),
        );
        api.pushResult = conflict;

        final report = await sync.sync('b-1');

        final c = await client();
        expect((c.name, c.version), ('Ana editada allá', 2));
        expect(report.push.conflicts, 1);
        expect(report.push.rejected, 1);
        expect(report.changedLocalData, isTrue);
      },
    );

    test(
      'queda el aviso: la operación rechazada por conflicto se conserva',
      () async {
        await localEdit('Ana editada aquí', base: 1);
        api.serverChanges.add(clientChange(5, 'c-1', name: 'Otra', version: 2));
        api.pushResult = conflict;

        await sync.sync('b-1');

        final notices = await sync.rejectedOperations('b-1');
        expect(notices.map((o) => (o.opId, o.type, o.errorCode)), [
          ('op-2', 'client.update', 'version_conflict'),
        ]);
        // Ya no cuenta como cambio sin enviar.
        expect(await sync.pendingCount(), 0);
      },
    );

    test('una edición encadenada sobre la descartada no se envía y también se descarta', () async {
      // Dos ediciones seguidas sin sincronizar: bases 1 y 2.
      await localEdit('Primera', base: 1);
      await localEdit('Segunda', base: 2);
      // El servidor pasó a la versión 2 por otro teléfono: la segunda
      // coincidiría con ella por casualidad si se enviara.
      api.serverChanges.add(
        clientChange(5, 'c-1', name: 'Del servidor', version: 2),
      );
      api.pushResult = conflict;

      final report = await sync.sync('b-1');

      expect(api.pushed.expand((b) => b).map((o) => o.opId), ['op-2']);
      final notices = await sync.rejectedOperations('b-1');
      expect(notices.map((o) => (o.opId, o.errorCode)), [
        ('op-2', 'version_conflict'),
        ('op-3', 'version_conflict'),
      ]);
      expect(report.push.conflicts, 2);
      expect((await client()).name, 'Del servidor');
    });

    test(
      'si la primera edición se aplica, la encadenada se envía después',
      () async {
        await localEdit('Primera', base: 1);
        await localEdit('Segunda', base: 2);

        await sync.pushPending('b-1');

        expect(api.pushed.map((b) => b.map((o) => o.opId).toList()), [
          ['op-2'],
          ['op-3'],
        ]);
        expect(await sync.pendingCount(), 0);
      },
    );

    test('la creación y su primera edición viajan juntas', () async {
      await insertOutboxOp(
        db,
        'op-a',
        'b-1',
        type: 'client.create',
        entityId: 'c-9',
      );
      await insertOutboxOp(
        db,
        'op-b',
        'b-1',
        type: 'client.update',
        entityId: 'c-9',
        baseVersion: 1,
      );

      await sync.pushPending('b-1');

      expect(api.pushed.map((b) => b.map((o) => o.opId).toList()), [
        ['op-a', 'op-b'],
      ]);
    });

    test('un rechazo que no es conflicto no descarta lo demás', () async {
      await localEdit('Primera', base: 1);
      await localEdit('Segunda', base: 2);
      api.pushResult = (op) => op.opId == 'op-2'
          ? OperationResult(
              opId: op.opId,
              status: OperationStatus.rejected,
              code: 'name_required',
              codes: const ['name_required'],
            )
          : null;

      await sync.pushPending('b-1');

      expect(api.pushed.map((b) => b.length), [1, 1]);
      final rejected = await sync.rejectedOperations('b-1');
      expect(rejected.map((o) => (o.opId, o.errorCode)), [
        ('op-2', 'name_required'),
      ]);
    });
  });
}
