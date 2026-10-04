import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/annul_result.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/data/repositories/fiado_repository.dart';
import 'package:pulperia_mobile/data/repositories/payment_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/ledger/fiado_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  late int idCounter;
  late FiadoRepository fiados;
  late PaymentRepository payments;
  late ClientRepository clients;

  setUp(() async {
    db = openDb();
    clock = DateTime.utc(2026, 10, 3, 10);
    idCounter = 0;
    String newId() => 'x-${++idCounter}';
    fiados = FiadoRepository(db, newId: newId, now: () => clock);
    payments = PaymentRepository(db, newId: newId, now: () => clock);
    clients = ClientRepository(db, newId: newId, now: () => clock);
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
    await insertClient(db, 'c-1', 'b-1');
    await insertClient(db, 'c-2', 'b-2');
  });
  tearDown(() => db.close());

  Future<List<OutboxOp>> outbox() => (db.select(
    db.outboxOps,
  )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

  Future<Fiado> fiadoRow(String id) =>
      (db.select(db.fiados)..where((f) => f.id.equals(id))).getSingle();

  Future<Payment> paymentRow(String id) =>
      (db.select(db.payments)..where((p) => p.id.equals(id))).getSingle();

  Future<AnnulResult<Fiado>> annulFiado(
    String id, {
    String businessId = 'b-1',
    String userId = 'u-9',
    Role role = Role.owner,
  }) => fiados.annul(
    businessId: businessId,
    userId: userId,
    role: role,
    fiadoId: id,
  );

  Future<AnnulResult<Payment>> annulPayment(
    String id, {
    String businessId = 'b-1',
    String userId = 'u-9',
    Role role = Role.owner,
  }) => payments.annul(
    businessId: businessId,
    userId: userId,
    role: role,
    paymentId: id,
  );

  Future<Money> balance() async =>
      (await clients.activeClients('b-1')).single.balance.amount;

  Future<void> advance() async => clock = clock.add(const Duration(hours: 2));

  group('anular un fiado (RF-43, RF-44)', () {
    setUp(() async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 6000);
      await insertFiadoItem(
        db,
        'i-1',
        'b-1',
        'f-1',
        quantity: 2000,
        unitPrice: 3000,
        subtotal: 6000,
      );
      await advance();
    });

    test('queda marcado como anulado, con quién y cuándo', () async {
      final result = await annulFiado('f-1', userId: 'u-9');

      expect(result, isA<Annulled<Fiado>>());
      final row = await fiadoRow('f-1');
      expect(row.annulledAt!.isAtSameMomentAs(clock), isTrue);
      expect(row.annulledBy, 'u-9');
    });

    test('el registro y sus ítems se conservan intactos', () async {
      await annulFiado('f-1');

      final row = await fiadoRow('f-1');
      expect([row.clientId, row.total, row.createdBy], ['c-1', 6000, 'u-1']);
      final item = await db.select(db.fiadoItems).getSingle();
      expect(
        [item.quantity, item.unitPrice, item.subtotal],
        [2000, 3000, 6000],
      );
    });

    test('RF-44: no cuenta en el saldo del cliente', () async {
      expect(await balance(), const Money(6000));

      await annulFiado('f-1');

      expect(await balance(), Money.zero);
    });

    test('solo se descuenta el anulado: los demás siguen contando', () async {
      await insertFiado(db, 'f-2', 'b-1', 'c-1', total: 4000);

      await annulFiado('f-1');

      expect(await balance(), const Money(4000));
    });

    test('encola un fiado.annul pendiente', () async {
      await annulFiado('f-1');

      final op = (await outbox()).last;
      expect(op.type, 'fiado.annul');
      expect(op.entityId, 'f-1');
      expect(op.businessId, 'b-1');
      expect(op.status, 'pending');
      expect(op.baseVersion, isNull);
      expect(op.payload, '{}');
      expect(op.createdAt.isAtSameMomentAs(clock), isTrue);
    });

    test('RF-45: el empleado no puede anular y no cambia nada', () async {
      final opsBefore = (await outbox()).length;

      final result = await annulFiado(
        'f-1',
        userId: 'u-2',
        role: Role.employee,
      );

      expect(result, isA<AnnulForbidden<Fiado>>());
      expect((await fiadoRow('f-1')).annulledAt, isNull);
      expect((await outbox()).length, opsBefore);
      expect(await balance(), const Money(6000));
    });

    test('un fiado que no existe, de otro negocio o que en realidad es un abono, no se encuentra', () async {
      await insertPayment(db, 'a-1', 'b-1', 'c-1', amount: 100);
      await insertFiado(db, 'f-9', 'b-2', 'c-2');

      expect(await annulFiado('no-existe'), isA<AnnulNotFound<Fiado>>());
      expect(await annulFiado('f-9'), isA<AnnulNotFound<Fiado>>());
      expect(await annulFiado('a-1'), isA<AnnulNotFound<Fiado>>());
      expect((await fiadoRow('f-9')).annulledAt, isNull);
    });

    test('anular uno ya anulado no cambia nada ni encola, y conserva quién y cuándo lo anuló', () async {
      await annulFiado('f-1', userId: 'u-9');
      final firstAt = (await fiadoRow('f-1')).annulledAt!;
      final opsBefore = (await outbox()).length;
      await advance();

      final result = await annulFiado('f-1', userId: 'u-3');

      expect((result as Annulled<Fiado>).alreadyAnnulled, isTrue);
      final row = await fiadoRow('f-1');
      expect(row.annulledBy, 'u-9');
      expect(row.annulledAt!.isAtSameMomentAs(firstAt), isTrue);
      expect((await outbox()).length, opsBefore);
    });

    test('si falla el encolado, no queda anulado', () async {
      await insertOutboxOp(db, 'x-${idCounter + 1}', 'b-1');

      await expectLater(annulFiado('f-1'), throwsA(isA<Exception>()));

      expect((await fiadoRow('f-1')).annulledAt, isNull);
      expect((await fiadoRow('f-1')).annulledBy, isNull);
    });

    test('se puede anular el fiado de un cliente archivado', () async {
      await clients.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: 'c-1',
      );

      final result = await annulFiado('f-1');

      expect(result, isA<Annulled<Fiado>>());
      expect(
        (await clients.archivedClients('b-1')).single.balance.amount,
        Money.zero,
      );
    });
  });

  group('anular un abono (RF-43, RF-44)', () {
    setUp(() async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 10000);
      await insertPayment(db, 'a-1', 'b-1', 'c-1', amount: 4000);
      await advance();
    });

    test('queda marcado como anulado, con quién y cuándo', () async {
      final result = await annulPayment('a-1', userId: 'u-9');

      expect(result, isA<Annulled<Payment>>());
      final row = await paymentRow('a-1');
      expect(row.annulledAt!.isAtSameMomentAs(clock), isTrue);
      expect(row.annulledBy, 'u-9');
    });

    test('el registro se conserva intacto', () async {
      await annulPayment('a-1');

      final row = await paymentRow('a-1');
      expect([row.clientId, row.amount, row.createdBy], ['c-1', 4000, 'u-1']);
    });

    test('RF-44: no cuenta en el saldo: la deuda vuelve a subir', () async {
      expect(await balance(), const Money(6000));

      await annulPayment('a-1');

      expect(await balance(), const Money(10000));
    });

    test('anular un abono que dejaba saldo a favor lo quita', () async {
      await insertPayment(db, 'a-2', 'b-1', 'c-1', amount: 9000);
      expect(
        (await clients.activeClients('b-1')).single.balance.label,
        BalanceLabel.credit,
      );

      await annulPayment('a-2');

      expect(await balance(), const Money(6000));
    });

    test('encola un payment.annul pendiente', () async {
      await annulPayment('a-1');

      final op = (await outbox()).last;
      expect(op.type, 'payment.annul');
      expect(op.entityId, 'a-1');
      expect(op.status, 'pending');
      expect(op.baseVersion, isNull);
      expect(op.payload, '{}');
      expect(op.createdAt.isAtSameMomentAs(clock), isTrue);
    });

    test('RF-45: el empleado no puede anular y no cambia nada', () async {
      final opsBefore = (await outbox()).length;

      final result = await annulPayment(
        'a-1',
        userId: 'u-2',
        role: Role.employee,
      );

      expect(result, isA<AnnulForbidden<Payment>>());
      expect((await paymentRow('a-1')).annulledAt, isNull);
      expect((await outbox()).length, opsBefore);
    });

    test('un abono que no existe, de otro negocio o que en realidad es un fiado, no se encuentra', () async {
      await insertPayment(db, 'a-9', 'b-2', 'c-2');

      expect(await annulPayment('no-existe'), isA<AnnulNotFound<Payment>>());
      expect(await annulPayment('a-9'), isA<AnnulNotFound<Payment>>());
      expect(await annulPayment('f-1'), isA<AnnulNotFound<Payment>>());
    });

    test('anular uno ya anulado no cambia nada ni encola', () async {
      await annulPayment('a-1', userId: 'u-9');
      final opsBefore = (await outbox()).length;
      await advance();

      final result = await annulPayment('a-1', userId: 'u-3');

      expect((result as Annulled<Payment>).alreadyAnnulled, isTrue);
      expect((await paymentRow('a-1')).annulledBy, 'u-9');
      expect((await outbox()).length, opsBefore);
    });

    test('si falla el encolado, no queda anulado', () async {
      await insertOutboxOp(db, 'x-${idCounter + 1}', 'b-1');

      await expectLater(annulPayment('a-1'), throwsA(isA<Exception>()));

      expect((await paymentRow('a-1')).annulledAt, isNull);
    });

    test('se puede anular el abono de un cliente archivado', () async {
      await clients.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: 'c-1',
      );

      expect(await annulPayment('a-1'), isA<Annulled<Payment>>());
    });
  });

  group('un movimiento solo se anula: no se edita ni se borra (RF-46)', () {
    test(
      'la cola no admite operaciones para editar ni borrar fiados o abonos',
      () async {
        for (final type in [
          'fiado.edit',
          'fiado.update',
          'fiado.delete',
          'payment.edit',
          'payment.update',
          'payment.delete',
        ]) {
          await expectLater(
            insertOutboxOp(db, 'op-$type', 'b-1', type: type),
            throwsA(isA<Exception>()),
            reason: type,
          );
        }
      },
    );

    test('lo único que cambia al anular es la marca de anulación', () async {
      await fiados.create(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: 'c-1',
        draft: const FiadoTotalOnly(Money(5000)),
      );
      final before = await db.select(db.fiados).getSingle();

      await annulFiado(before.id);

      final after = await db.select(db.fiados).getSingle();
      expect(
        [
          after.id,
          after.businessId,
          after.clientId,
          after.total,
          after.createdBy,
          after.occurredAt,
        ],
        [
          before.id,
          before.businessId,
          before.clientId,
          before.total,
          before.createdBy,
          before.occurredAt,
        ],
      );
      expect(before.annulledAt, isNull);
      expect(after.annulledAt, isNotNull);
    });

    test('cada anulación guarda el usuario que la hizo, no el que creó el movimiento (RF-49)', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1');

      await annulFiado('f-1', userId: 'u-owner');

      final row = await fiadoRow('f-1');
      expect(row.createdBy, 'u-1');
      expect(row.annulledBy, 'u-owner');
    });

    test('el payload de una anulación no lleva datos que cambiar', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1');
      await annulFiado('f-1');

      expect(jsonDecode((await outbox()).single.payload), isEmpty);
    });
  });
}
