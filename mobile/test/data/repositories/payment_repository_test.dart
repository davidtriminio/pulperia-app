import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/data/repositories/payment_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  late int idCounter;
  late PaymentRepository repo;
  late ClientRepository clients;

  setUp(() async {
    db = openDb();
    clock = DateTime.utc(2026, 10, 3, 10);
    idCounter = 0;
    String newId() => 'p-${++idCounter}';
    repo = PaymentRepository(db, newId: newId, now: () => clock);
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

  Future<PaymentSaveResult> pay(
    int amount, {
    String businessId = 'b-1',
    String clientId = 'c-1',
    String userId = 'u-1',
    Role role = Role.owner,
  }) => repo.create(
    businessId: businessId,
    userId: userId,
    role: role,
    clientId: clientId,
    amount: Money(amount),
  );

  Future<void> archiveClient(String id) => clients.archive(
    businessId: 'b-1',
    userId: 'u-1',
    role: Role.owner,
    clientId: id,
  );

  group('registrar un abono (RF-37)', () {
    test(
      'guarda el monto, cuándo ocurrió y quién lo registró (RF-49)',
      () async {
        final result = await pay(3000, userId: 'u-7');

        final saved = (result as PaymentSaved).payment;
        final stored = await db.select(db.payments).getSingle();
        expect(stored.id, saved.id);
        expect(stored.businessId, 'b-1');
        expect(stored.clientId, 'c-1');
        expect(stored.amount, 3000);
        expect(stored.occurredAt.isAtSameMomentAs(clock), isTrue);
        expect(stored.createdBy, 'u-7');
        expect(stored.annulledAt, isNull);
        expect(stored.annulledBy, isNull);
        expect(stored.serverSeq, isNull);
      },
    );

    test(
      'no se asocia a ningún fiado ni ítem: reduce el saldo total',
      () async {
        final columns = [for (final c in db.payments.$columns) c.name];

        expect(columns, isNot(contains('fiado_id')));
        expect(columns, isNot(contains('item_id')));
      },
    );

    test('reduce el saldo del cliente', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 10000);

      await pay(3000);

      expect(
        (await clients.activeClients('b-1')).single.balance.amount,
        const Money(7000),
      );
    });

    test('varios abonos se acumulan', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 10000);

      await pay(2000);
      await pay(1500);
      await pay(500);

      expect(
        (await clients.activeClients('b-1')).single.balance.amount,
        const Money(6000),
      );
    });

    test(
      'un abono mayor que la deuda se acepta y deja saldo a favor (RF-39)',
      () async {
        await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 10000);

        final result = await pay(12000);

        expect(result, isA<PaymentSaved>());
        final balance = (await clients.activeClients('b-1')).single.balance;
        expect(balance, const Balance(Money(-2000)));
        expect(balance.label, BalanceLabel.credit);
      },
    );

    test(
      'un abono a un cliente sin deuda también se acepta y queda a favor',
      () async {
        await pay(5000);

        expect(
          (await clients.activeClients('b-1')).single.balance.credit,
          const Money(5000),
        );
      },
    );

    test('un monto grande se acepta', () async {
      expect(await pay(99999999000), isA<PaymentSaved>());
    });
  });

  group('a un cliente archivado (RF-75)', () {
    test('se guarda aunque el cliente esté archivado', () async {
      await archiveClient('c-1');

      final result = await pay(2000);

      expect(result, isA<PaymentSaved>());
      expect((await db.select(db.payments).getSingle()).clientId, 'c-1');
    });

    test('reduce el saldo del cliente archivado', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 9000);
      await archiveClient('c-1');

      await pay(4000);

      final archived = await clients.archivedClients('b-1');
      expect(archived.single.balance.amount, const Money(5000));
    });

    test('el cliente sigue archivado después del abono', () async {
      await archiveClient('c-1');

      await pay(2000);

      expect(await clients.activeClients('b-1'), isEmpty);
      expect((await clients.archivedClients('b-1')).length, 1);
    });

    test('puede saldar del todo a un archivado', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 6000);
      await archiveClient('c-1');

      await pay(6000);

      expect(
        (await clients.archivedClients('b-1')).single.balance.label,
        BalanceLabel.settled,
      );
    });
  });

  group('se guarda junto con su operación en la cola (RF-51)', () {
    test('encola un payment.create pendiente con el contenido', () async {
      final result = await pay(3000);

      final saved = (result as PaymentSaved).payment;
      final ops = await outbox();
      expect(ops.length, 1);
      final op = ops.single;
      expect(op.type, 'payment.create');
      expect(op.entityId, saved.id);
      expect(op.businessId, 'b-1');
      expect(op.status, 'pending');
      expect(op.baseVersion, isNull);
      expect(op.createdAt.isAtSameMomentAs(clock), isTrue);
      expect(op.opId, isNot(saved.id));
      expect(jsonDecode(op.payload), {
        'clientId': 'c-1',
        'amount': 3000,
        'occurredAt': '2026-10-03T10:00:00.000Z',
      });
    });

    test('si falla el encolado, no queda el abono guardado', () async {
      // El id de la operación será 'p-2' (el abono usa 'p-1').
      await insertOutboxOp(db, 'p-2', 'b-1');

      await expectLater(pay(3000), throwsA(isA<Exception>()));

      expect(await db.select(db.payments).get(), isEmpty);
      expect(
        (await outbox()).length,
        1,
        reason: 'solo la operación preexistente',
      );
    });

    test('varios abonos se encolan en orden, cada uno con su fecha', () async {
      await pay(1000);
      clock = clock.add(const Duration(minutes: 5));
      await pay(2000);

      final ops = await outbox();
      expect(
        [for (final o in ops) (jsonDecode(o.payload) as Map)['amount']],
        [1000, 2000],
      );
      expect(ops[1].createdAt.isAfter(ops[0].createdAt), isTrue);
      expect(
        {for (final p in await db.select(db.payments).get()) p.id}.length,
        2,
      );
    });
  });

  group('lo que no se acepta (RF-38)', () {
    test('monto cero', () async {
      final result = await pay(0);

      expect((result as PaymentRejected).error.code, 'amount_not_positive');
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await outbox(), isEmpty);
    });

    test('monto negativo', () async {
      final result = await pay(-3000);

      expect((result as PaymentRejected).error.code, 'amount_not_positive');
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await outbox(), isEmpty);
    });

    test(
      'con montos enteros, un abono con centavos se rechaza (RF-36)',
      () async {
        await (db.update(db.businesses)..where((b) => b.id.equals('b-1')))
            .write(const BusinessesCompanion(amountMode: Value('integer')));

        final result = await pay(1250);

        expect((result as PaymentRejected).error.code, 'amount_not_whole');
        expect(await db.select(db.payments).get(), isEmpty);
      },
    );

    test('con montos enteros, un lempira entero se acepta', () async {
      await (db.update(db.businesses)..where((b) => b.id.equals('b-1'))).write(
        const BusinessesCompanion(amountMode: Value('integer')),
      );

      expect(await pay(5000), isA<PaymentSaved>());
    });

    test(
      'un cliente que no existe, o de otro negocio, no se encuentra',
      () async {
        expect(
          await pay(1000, clientId: 'no-existe'),
          isA<PaymentClientNotFound>(),
        );
        expect(await pay(1000, clientId: 'c-2'), isA<PaymentClientNotFound>());
        expect(await db.select(db.payments).get(), isEmpty);
        expect(await outbox(), isEmpty);
      },
    );

    test(
      'un cliente que no existe se avisa antes que un monto inválido',
      () async {
        expect(
          await pay(0, clientId: 'no-existe'),
          isA<PaymentClientNotFound>(),
        );
      },
    );

    test('un negocio que no existe lanza error y no deja nada', () async {
      await expectLater(
        pay(1000, businessId: 'no-existe'),
        throwsA(isA<Object>()),
      );

      expect(await db.select(db.payments).get(), isEmpty);
    });
  });

  group('permisos', () {
    test('el empleado también registra abonos (RF-48)', () async {
      final result = await pay(1000, userId: 'u-2', role: Role.employee);

      expect(result, isA<PaymentSaved>());
      expect((await db.select(db.payments).getSingle()).createdBy, 'u-2');
    });
  });
}
