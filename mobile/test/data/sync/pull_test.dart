import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pulperia_mobile/data/local/app_database.dart';
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
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2', name: 'Abarrotes Beto');
  });

  tearDown(() => db.close());

  Future<int> cursorOf(String businessId) async {
    final row = await (db.select(
      db.syncStates,
    )..where((s) => s.businessId.equals(businessId))).getSingleOrNull();
    return row?.cursor ?? 0;
  }

  Future<Client> client(String id) =>
      (db.select(db.clients)..where((c) => c.id.equals(id))).getSingle();

  group('recepción de cambios por cursor (RF-52)', () {
    test('guarda clientes, productos, fiados con ítems y abonos', () async {
      api.serverChanges.addAll([
        clientChange(1, 'c-1'),
        productChange(2, 'p-1'),
        fiadoChange(3, 'f-1', 'c-1'),
        paymentChange(4, 'a-1', 'c-1'),
      ]);

      final report = await sync.pullChanges('b-1');

      expect(report.received, 4);
      expect((await client('c-1')).name, 'Ana López');
      expect((await client('c-1')).businessId, 'b-1');
      final product = await (db.select(db.products)).getSingle();
      expect(
        (product.name, product.price, product.unit),
        ('Arroz', 2500, 'pound'),
      );
      final fiado = await db.select(db.fiados).getSingle();
      expect((fiado.total, fiado.serverSeq, fiado.createdBy), (1400, 3, 'u-9'));
      final items = await db.select(db.fiadoItems).get();
      expect(items.map((i) => (i.description, i.quantity, i.subtotal)), [
        ('Arroz', 500, 1400),
      ]);
      final payment = await db.select(db.payments).getSingle();
      expect((payment.amount, payment.serverSeq), (500, 4));
    });

    test('guarda el cursor y la siguiente vez pide desde ahí', () async {
      api.serverChanges.addAll([
        clientChange(5, 'c-1'),
        clientChange(9, 'c-2'),
      ]);

      await sync.pullChanges('b-1');
      expect(await cursorOf('b-1'), 9);

      await sync.pullChanges('b-1');
      expect(api.pulledFrom, [0, 9]);
      expect(await cursorOf('b-1'), 9);
    });

    test('el cursor es de cada negocio', () async {
      api.serverChanges.add(clientChange(5, 'c-1'));
      await sync.pullChanges('b-1');

      expect(await cursorOf('b-2'), 0);
    });

    test('sigue las páginas hasta que no haya más', () async {
      api.pageSize = 2;
      api.serverChanges.addAll([
        for (var i = 1; i <= 5; i++)
          clientChange(i, 'c-$i', name: 'Cliente $i'),
      ]);

      final report = await sync.pullChanges('b-1');

      expect(report.received, 5);
      expect(api.pulledFrom, [0, 2, 4]);
      expect(await db.select(db.clients).get(), hasLength(5));
      expect(await cursorOf('b-1'), 5);
    });

    test('aplicar dos veces la misma página no duplica nada', () async {
      api.serverChanges.addAll([
        clientChange(1, 'c-1'),
        fiadoChange(2, 'f-1', 'c-1'),
        paymentChange(3, 'a-1', 'c-1'),
      ]);
      await sync.pullChanges('b-1');

      // El cursor se pierde (por ejemplo, un reinstalado a medias): se vuelve
      // a recibir todo.
      await db.delete(db.syncStates).go();
      await sync.pullChanges('b-1');

      expect(await db.select(db.clients).get(), hasLength(1));
      expect(await db.select(db.fiados).get(), hasLength(1));
      expect(await db.select(db.fiadoItems).get(), hasLength(1));
      expect(await db.select(db.payments).get(), hasLength(1));
      expect(await cursorOf('b-1'), 3);
    });

    test('un cambio posterior reemplaza la versión local', () async {
      api.serverChanges.add(clientChange(1, 'c-1', name: 'Ana'));
      await sync.pullChanges('b-1');

      api.serverChanges.add(
        clientChange(2, 'c-1', name: 'Ana López', version: 2, archived: true),
      );
      api.serverChanges.removeWhere((c) => c.seq == 1);
      await sync.pullChanges('b-1');

      final c = await client('c-1');
      expect((c.name, c.version, c.archived), ('Ana López', 2, true));
    });

    test('una página vacía deja el cursor donde estaba', () async {
      api.serverChanges.add(clientChange(4, 'c-1'));
      await sync.pullChanges('b-1');

      final report = await sync.pullChanges('b-1');

      expect(report.received, 0);
      expect(await cursorOf('b-1'), 4);
    });

    test('es todo o nada: si una página falla no avanza el cursor', () async {
      api.serverChanges.addAll([
        clientChange(1, 'c-1'),
        // El cliente de este fiado nunca llega.
        fiadoChange(2, 'f-1', 'c-desconocido'),
      ]);

      await expectLater(sync.pullChanges('b-1'), throwsA(anything));

      expect(await db.select(db.clients).get(), isEmpty);
      expect(await cursorOf('b-1'), 0);
    });
  });

  group('no pisa lo que el usuario cambió y aún no se envió (D-8)', () {
    Future<void> localEdit(String name, {required int base}) async {
      await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
        ClientsCompanion(name: Value(name), version: Value(base + 1)),
      );
      await insertOutboxOp(
        db,
        'op-edit',
        'b-1',
        type: 'client.update',
        entityId: 'c-1',
        baseVersion: base,
      );
    }

    setUp(() async {
      api.serverChanges.add(clientChange(1, 'c-1', name: 'Ana', version: 1));
      await sync.pullChanges('b-1');
    });

    test(
      'una versión que ya conocíamos no borra la edición pendiente',
      () async {
        await localEdit('Ana editada', base: 1);
        // El servidor entrega otra vez la versión 1.
        api.serverChanges
          ..clear()
          ..add(clientChange(2, 'c-1', name: 'Ana', version: 1));

        await sync.pullChanges('b-1');

        final c = await client('c-1');
        expect((c.name, c.version), ('Ana editada', 2));
      },
    );

    test(
      'una versión más nueva del servidor gana sobre la edición pendiente',
      () async {
        await localEdit('Ana editada', base: 1);
        api.serverChanges
          ..clear()
          ..add(
            clientChange(2, 'c-1', name: 'Ana del otro teléfono', version: 2),
          );

        await sync.pullChanges('b-1');

        final c = await client('c-1');
        expect((c.name, c.version), ('Ana del otro teléfono', 2));
      },
    );
  });

  group('anulaciones', () {
    final annulled = DateTime.utc(2026, 10, 9, 16);

    test(
      'una anulación hecha en otro teléfono marca el movimiento local',
      () async {
        api.serverChanges.addAll([
          clientChange(1, 'c-1'),
          fiadoChange(2, 'f-1', 'c-1'),
          paymentChange(3, 'a-1', 'c-1'),
        ]);
        await sync.pullChanges('b-1');

        api.serverChanges
          ..removeWhere((c) => c.seq > 1)
          ..addAll([
            fiadoChange(4, 'f-1', 'c-1', annulledAt: annulled),
            paymentChange(5, 'a-1', 'c-1', annulledAt: annulled),
          ]);
        await sync.pullChanges('b-1');

        final fiado = await db.select(db.fiados).getSingle();
        expect(
          (fiado.annulledAt, fiado.annulledBy, fiado.serverSeq),
          (annulled, 'u-9', 4),
        );
        final payment = await db.select(db.payments).getSingle();
        expect(payment.annulledAt, annulled);
        expect(await db.select(db.fiadoItems).get(), hasLength(1));
      },
    );

    test('una anulación local pendiente no se deshace', () async {
      api.serverChanges.addAll([
        clientChange(1, 'c-1'),
        fiadoChange(2, 'f-1', 'c-1'),
      ]);
      await sync.pullChanges('b-1');
      await (db.update(db.fiados)..where((f) => f.id.equals('f-1'))).write(
        FiadosCompanion(
          annulledAt: Value(annulled),
          annulledBy: const Value('u-1'),
        ),
      );
      await insertOutboxOp(
        db,
        'op-annul',
        'b-1',
        type: 'fiado.annul',
        entityId: 'f-1',
      );
      api.serverChanges
        ..clear()
        ..add(fiadoChange(3, 'f-1', 'c-1'));

      await sync.pullChanges('b-1');

      final fiado = await db.select(db.fiados).getSingle();
      expect(fiado.annulledAt, annulled);
      expect(fiado.annulledBy, 'u-1');
    });
  });
}
