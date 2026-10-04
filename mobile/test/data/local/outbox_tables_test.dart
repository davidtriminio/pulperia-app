import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/db_fixtures.dart';

const operationTypes = [
  'client.create',
  'client.update',
  'client.archive',
  'client.restore',
  'product.create',
  'product.update',
  'product.archive',
  'fiado.create',
  'payment.create',
  'fiado.annul',
  'payment.annul',
];

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openDb();
    await insertBusiness(db, 'b-1');
  });
  tearDown(() => db.close());

  group('cola de operaciones: se guarda y se lee una operación (RF-51)', () {
    test('con sus valores por defecto: pendiente y sin error', () async {
      await insertOutboxOp(
        db,
        'op-1',
        'b-1',
        type: 'fiado.create',
        entityId: 'f-1',
        payload: '{"total":5000}',
      );

      final op = await db.select(db.outboxOps).getSingle();
      expect(op.opId, 'op-1');
      expect(op.businessId, 'b-1');
      expect(op.type, 'fiado.create');
      expect(op.entityId, 'f-1');
      expect(op.payload, '{"total":5000}');
      expect(op.baseVersion, isNull);
      expect(op.status, 'pending');
      expect(op.errorCode, isNull);
      expect(op.createdAt.isAtSameMomentAs(created), isTrue);
    });

    test('una edición lleva la versión base (D-8)', () async {
      await insertOutboxOp(
        db,
        'op-1',
        'b-1',
        type: 'client.update',
        baseVersion: 3,
      );

      expect((await db.select(db.outboxOps).getSingle()).baseVersion, 3);
    });

    test('el contenido se guarda tal cual, con tildes y eñes', () async {
      const payload = '{"name":"Niño Muñoz","note":"Paga los viernes ñandú"}';
      await insertOutboxOp(db, 'op-1', 'b-1', payload: payload);

      expect((await db.select(db.outboxOps).getSingle()).payload, payload);
    });

    test('acepta todos los tipos de operación del plan', () async {
      for (var i = 0; i < operationTypes.length; i++) {
        await insertOutboxOp(db, 'op-$i', 'b-1', type: operationTypes[i]);
      }

      final stored = await db.select(db.outboxOps).get();
      expect({for (final o in stored) o.type}, operationTypes.toSet());
    });

    test('rechaza un tipo de operación desconocido', () async {
      expect(
        insertOutboxOp(db, 'op-1', 'b-1', type: 'client.delete'),
        throwsA(isA<Exception>()),
      );
      expect(
        insertOutboxOp(db, 'op-2', 'b-1', type: 'fiado.edit'),
        throwsA(isA<Exception>()),
      );
    });

    test('la fecha de creación se guarda como texto en UTC', () async {
      final local = DateTime.utc(2026, 1, 15, 3, 4, 5).toLocal();
      await insertOutboxOp(db, 'op-1', 'b-1', createdAt: local);

      final raw = await db
          .customSelect('SELECT created_at FROM outbox_ops')
          .getSingle();
      expect(raw.read<String>('created_at'), '2026-01-15T03:04:05.000Z');
    });
  });

  group('estado de una operación', () {
    test('admite pendiente, enviada y rechazada', () async {
      await insertOutboxOp(db, 'op-1', 'b-1', status: 'pending');
      await insertOutboxOp(db, 'op-2', 'b-1', status: 'sent');
      await insertOutboxOp(
        db,
        'op-3',
        'b-1',
        status: 'rejected',
        errorCode: 'version_conflict',
      );

      final byId = {
        for (final o in await db.select(db.outboxOps).get()) o.opId: o,
      };
      expect(byId['op-1']!.status, 'pending');
      expect(byId['op-2']!.status, 'sent');
      expect(byId['op-3']!.status, 'rejected');
      expect(byId['op-3']!.errorCode, 'version_conflict');
    });

    test('rechaza un estado desconocido', () async {
      expect(
        insertOutboxOp(db, 'op-1', 'b-1', status: 'done'),
        throwsA(isA<Exception>()),
      );
    });

    test('una operación rechazada debe traer su código de error', () async {
      expect(
        insertOutboxOp(db, 'op-1', 'b-1', status: 'rejected'),
        throwsA(isA<Exception>()),
      );
    });

    test('solo una operación rechazada puede traer código de error', () async {
      expect(
        insertOutboxOp(db, 'op-1', 'b-1', status: 'pending', errorCode: 'x'),
        throwsA(isA<Exception>()),
      );
      expect(
        insertOutboxOp(db, 'op-2', 'b-1', status: 'sent', errorCode: 'x'),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'una operación pendiente puede pasar a enviada y a rechazada',
      () async {
        await insertOutboxOp(db, 'op-1', 'b-1');

        await (db.update(db.outboxOps)..where((o) => o.opId.equals('op-1')))
            .write(const OutboxOpsCompanion(status: Value('sent')));
        expect((await db.select(db.outboxOps).getSingle()).status, 'sent');

        await (db.update(
          db.outboxOps,
        )..where((o) => o.opId.equals('op-1'))).write(
          const OutboxOpsCompanion(
            status: Value('rejected'),
            errorCode: Value('permission_denied'),
          ),
        );
        final op = await db.select(db.outboxOps).getSingle();
        expect(op.status, 'rejected');
        expect(op.errorCode, 'permission_denied');
      },
    );
  });

  group('orden e identidad', () {
    test('el id de operación no se repite: reenviar no duplica', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');

      expect(insertOutboxOp(db, 'op-1', 'b-1'), throwsA(isA<Exception>()));
    });

    test(
      'se leen en el orden en que se encolaron, aunque tengan la misma fecha',
      () async {
        for (final id in ['op-c', 'op-a', 'op-b']) {
          await insertOutboxOp(db, id, 'b-1', createdAt: created);
        }

        final ops = await (db.select(
          db.outboxOps,
        )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

        expect([for (final o in ops) o.opId], ['op-c', 'op-a', 'op-b']);
      },
    );

    test('el orden local solo crece', () async {
      await insertOutboxOp(db, 'op-1', 'b-1');
      await insertOutboxOp(db, 'op-2', 'b-1');
      await db.delete(db.outboxOps).go();
      await insertOutboxOp(db, 'op-3', 'b-1');

      final seqs = (await db.select(db.outboxOps).get())
          .map((o) => o.localSeq)
          .toList();
      expect(seqs.single, greaterThan(2));
    });
  });

  group('pendientes por negocio (RF-57)', () {
    test('cuenta solo las pendientes del negocio pedido', () async {
      await insertBusiness(db, 'b-2');
      await insertOutboxOp(db, 'op-1', 'b-1');
      await insertOutboxOp(db, 'op-2', 'b-1');
      await insertOutboxOp(db, 'op-3', 'b-1', status: 'sent');
      await insertOutboxOp(
        db,
        'op-4',
        'b-1',
        status: 'rejected',
        errorCode: 'x',
      );
      await insertOutboxOp(db, 'op-5', 'b-2');

      final pending =
          await (db.select(db.outboxOps)..where(
                (o) => o.businessId.equals('b-1') & o.status.equals('pending'),
              ))
              .get();

      expect([for (final o in pending) o.opId], ['op-1', 'op-2']);
    });

    test('una operación de un negocio que no existe se rechaza', () async {
      expect(
        insertOutboxOp(db, 'op-1', 'no-existe'),
        throwsA(isA<Exception>()),
      );
    });

    test('las operaciones llevan business_id', () {
      expect([
        for (final c in db.outboxOps.$columns) c.name,
      ], contains('business_id'));
    });
  });

  group('cursor de sincronización', () {
    test('empieza en cero y se guarda por negocio', () async {
      await db
          .into(db.syncStates)
          .insert(SyncStatesCompanion.insert(businessId: 'b-1'));

      final state = await db.select(db.syncStates).getSingle();
      expect(state.businessId, 'b-1');
      expect(state.cursor, 0);
    });

    test('se actualiza al recibir cambios', () async {
      await db
          .into(db.syncStates)
          .insert(SyncStatesCompanion.insert(businessId: 'b-1'));

      await (db.update(db.syncStates)..where((s) => s.businessId.equals('b-1')))
          .write(const SyncStatesCompanion(cursor: Value(42)));

      expect((await db.select(db.syncStates).getSingle()).cursor, 42);
    });

    test('cada negocio tiene su propio cursor', () async {
      await insertBusiness(db, 'b-2');
      await db
          .into(db.syncStates)
          .insert(
            SyncStatesCompanion.insert(
              businessId: 'b-1',
              cursor: const Value(10),
            ),
          );
      await db
          .into(db.syncStates)
          .insert(
            SyncStatesCompanion.insert(
              businessId: 'b-2',
              cursor: const Value(99),
            ),
          );

      final cursors = {
        for (final s in await db.select(db.syncStates).get())
          s.businessId: s.cursor,
      };
      expect(cursors, {'b-1': 10, 'b-2': 99});
    });

    test('un negocio no tiene dos cursores', () async {
      await db
          .into(db.syncStates)
          .insert(SyncStatesCompanion.insert(businessId: 'b-1'));

      expect(
        db
            .into(db.syncStates)
            .insert(SyncStatesCompanion.insert(businessId: 'b-1')),
        throwsA(isA<Exception>()),
      );
    });

    test('el cursor nunca es negativo', () async {
      expect(
        db
            .into(db.syncStates)
            .insert(
              SyncStatesCompanion.insert(
                businessId: 'b-1',
                cursor: const Value(-1),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('un cursor de un negocio que no existe se rechaza', () async {
      expect(
        db
            .into(db.syncStates)
            .insert(SyncStatesCompanion.insert(businessId: 'no-existe')),
        throwsA(isA<Exception>()),
      );
    });
  });
}
