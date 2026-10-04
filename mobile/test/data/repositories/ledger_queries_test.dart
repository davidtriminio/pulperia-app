import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/ledger_queries.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';
import '../../support/shared_vectors.dart';

DateTime at(int minute, [int second = 0]) =>
    DateTime.utc(2026, 10, 2, 15, minute, second);

void main() {
  late AppDatabase db;
  late LedgerQueries queries;
  final annulledAt = DateTime.utc(2026, 10, 5, 8);

  setUp(() async {
    db = openDb();
    queries = LedgerQueries(db);
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
    await insertClient(db, 'c-1', 'b-1');
  });
  tearDown(() => db.close());

  List<String> ids(ClientHistory h) => [for (final e in h.entries) e.id];

  group('saldo con los vectores compartidos (RF-40, RF-42, RF-44)', () {
    final cases = loadVectorCases('balance.json');

    test('hay al menos 15 casos', () {
      expect(cases.length, greaterThanOrEqualTo(15));
    });

    for (final c in cases) {
      test(c.name, () async {
        var n = 0;
        for (final m in c.input['movements'] as List<dynamic>) {
          final movement = m as Map<String, dynamic>;
          final annulled = movement['annulled'] as bool;
          n++;
          if (movement['type'] == 'fiado') {
            await insertFiado(
              db,
              'f-$n',
              'b-1',
              'c-1',
              total: movement['amount'] as int,
              annulledAt: annulled ? annulledAt : null,
              annulledBy: annulled ? 'u-9' : null,
            );
          } else {
            await insertPayment(
              db,
              'a-$n',
              'b-1',
              'c-1',
              amount: movement['amount'] as int,
              annulledAt: annulled ? annulledAt : null,
              annulledBy: annulled ? 'u-9' : null,
            );
          }
        }

        final balance = await queries.balanceOf('b-1', 'c-1');

        expect(balance!.amount.minorUnits, c.expected['balance']);
        expect(balance.label.id, c.expected['label']);
        final history = await queries.historyOf('b-1', 'c-1');
        expect(history!.balance, balance);
      });
    }
  });

  group('historial de un cliente (RF-41)', () {
    test(
      'un cliente sin movimientos tiene historial vacío y saldo saldado',
      () async {
        final history = await queries.historyOf('b-1', 'c-1');

        expect(history!.client.id, 'c-1');
        expect(history.entries, isEmpty);
        expect(history.balance.label, BalanceLabel.settled);
      },
    );

    test('mezcla fiados y abonos en orden cronológico, del más antiguo al más reciente', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 5000,
        occurredAt: at(30),
      );
      await insertPayment(
        db,
        'a-1',
        'b-1',
        'c-1',
        amount: 2000,
        occurredAt: at(10),
      );
      await insertFiado(
        db,
        'f-2',
        'b-1',
        'c-1',
        total: 3000,
        occurredAt: at(20),
      );
      await insertPayment(
        db,
        'a-2',
        'b-1',
        'c-1',
        amount: 1000,
        occurredAt: at(40),
      );

      final history = await queries.historyOf('b-1', 'c-1');

      expect(ids(history!), ['a-1', 'f-2', 'f-1', 'a-2']);
      expect(
        [for (final e in history.entries) e.kind],
        [
          MovementKind.payment,
          MovementKind.fiado,
          MovementKind.fiado,
          MovementKind.payment,
        ],
      );
    });

    test(
      'cada entrada trae su monto, fecha, autor y orden de servidor',
      () async {
        await insertFiado(
          db,
          'f-1',
          'b-1',
          'c-1',
          total: 5000,
          occurredAt: at(10),
          serverSeq: 7,
        );

        final entry = (await queries.historyOf('b-1', 'c-1'))!.entries.single;

        expect(entry.amount, const Money(5000));
        expect(entry.occurredAt.isAtSameMomentAs(at(10)), isTrue);
        expect(entry.createdBy, 'u-1');
        expect(entry.serverSeq, 7);
        expect(entry.isAnnulled, isFalse);
        expect(entry.annulledBy, isNull);
        expect(entry.annulledAt, isNull);
      },
    );

    test('un fiado con ítems trae su detalle: descripción, cantidad, precio y subtotal', () async {
      await insertProduct(db, 'p-1', 'b-1');
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 4500,
        occurredAt: at(10),
      );
      await insertFiadoItem(
        db,
        'i-1',
        'b-1',
        'f-1',
        productId: 'p-1',
        description: 'Arroz',
        quantity: 2000,
        unitPrice: 1500,
        subtotal: 3000,
      );
      await insertFiadoItem(
        db,
        'i-2',
        'b-1',
        'f-1',
        description: 'Queso suelto',
        quantity: 500,
        unitPrice: 3000,
        subtotal: 1500,
      );

      final entry = (await queries.historyOf('b-1', 'c-1'))!.entries.single;

      expect(entry.items.length, 2);
      expect(entry.items[0].description, 'Arroz');
      expect(entry.items[0].productId, 'p-1');
      expect(entry.items[0].quantity, 2000);
      expect(entry.items[0].unitPrice, 1500);
      expect(entry.items[0].subtotal, 3000);
      expect(entry.items[1].description, 'Queso suelto');
      expect(entry.items[1].productId, isNull);
    });

    test('un fiado solo con total y un abono no traen ítems', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 5000,
        occurredAt: at(10),
      );
      await insertPayment(
        db,
        'a-1',
        'b-1',
        'c-1',
        amount: 1000,
        occurredAt: at(20),
      );

      final entries = (await queries.historyOf('b-1', 'c-1'))!.entries;

      expect(entries[0].items, isEmpty);
      expect(entries[1].items, isEmpty);
    });

    test('los ítems de un fiado no aparecen en otro', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 2500,
        occurredAt: at(10),
      );
      await insertFiadoItem(
        db,
        'i-1',
        'b-1',
        'f-1',
        description: 'Solo del primero',
      );
      await insertFiado(
        db,
        'f-2',
        'b-1',
        'c-1',
        total: 2500,
        occurredAt: at(20),
      );
      await insertFiadoItem(
        db,
        'i-2',
        'b-1',
        'f-2',
        description: 'Solo del segundo',
      );

      final entries = (await queries.historyOf('b-1', 'c-1'))!.entries;

      expect(
        [for (final i in entries[0].items) i.description],
        ['Solo del primero'],
      );
      expect(
        [for (final i in entries[1].items) i.description],
        ['Solo del segundo'],
      );
    });
  });

  group('los anulados se incluyen, marcados, y no cuentan en el saldo (RF-41, RF-44)', () {
    test('un fiado anulado aparece marcado, con quién y cuándo', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 5000,
        occurredAt: at(10),
        annulledAt: annulledAt,
        annulledBy: 'u-9',
      );

      final history = await queries.historyOf('b-1', 'c-1');
      final entry = history!.entries.single;

      expect(entry.isAnnulled, isTrue);
      expect(entry.annulledBy, 'u-9');
      expect(entry.annulledAt!.isAtSameMomentAs(annulledAt), isTrue);
      expect(history.balance.label, BalanceLabel.settled);
    });

    test('un abono anulado aparece marcado y la deuda no baja', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 5000,
        occurredAt: at(10),
      );
      await insertPayment(
        db,
        'a-1',
        'b-1',
        'c-1',
        amount: 3000,
        occurredAt: at(20),
        annulledAt: annulledAt,
        annulledBy: 'u-9',
      );

      final history = await queries.historyOf('b-1', 'c-1');

      expect(history!.entries.where((e) => e.isAnnulled).map((e) => e.id), [
        'a-1',
      ]);
      expect(history.balance.amount, const Money(5000));
    });

    test('un fiado anulado conserva su detalle de ítems', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 2500,
        annulledAt: annulledAt,
        annulledBy: 'u-9',
      );
      await insertFiadoItem(db, 'i-1', 'b-1', 'f-1', description: 'Arroz');

      final entry = (await queries.historyOf('b-1', 'c-1'))!.entries.single;

      expect(entry.isAnnulled, isTrue);
      expect(entry.items.single.description, 'Arroz');
    });
  });

  group('saldo a favor (RF-42)', () {
    test('un saldo negativo se identifica como saldo a favor', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        total: 10000,
        occurredAt: at(10),
      );
      await insertPayment(
        db,
        'a-1',
        'b-1',
        'c-1',
        amount: 12000,
        occurredAt: at(20),
      );

      final history = await queries.historyOf('b-1', 'c-1');

      expect(history!.balance.amount, const Money(-2000));
      expect(history.balance.label, BalanceLabel.credit);
      expect(history.balance.credit, const Money(2000));
      expect(history.balance.debt, Money.zero);
    });
  });

  group('orden estable de los empates (RF-41, D-18)', () {
    test(
      'con la misma fecha, va primero el que llegó antes al servidor',
      () async {
        await insertFiado(
          db,
          'f-b',
          'b-1',
          'c-1',
          occurredAt: at(10),
          serverSeq: 9,
        );
        await insertPayment(
          db,
          'a-a',
          'b-1',
          'c-1',
          occurredAt: at(10),
          serverSeq: 4,
        );

        expect(ids((await queries.historyOf('b-1', 'c-1'))!), ['a-a', 'f-b']);
      },
    );

    test(
      'con la misma fecha, lo ya sincronizado va antes que lo pendiente',
      () async {
        await insertFiado(db, 'f-1', 'b-1', 'c-1', occurredAt: at(10));
        await insertPayment(
          db,
          'a-1',
          'b-1',
          'c-1',
          occurredAt: at(10),
          serverSeq: 99,
        );

        expect(ids((await queries.historyOf('b-1', 'c-1'))!), ['a-1', 'f-1']);
      },
    );

    test('sin orden de servidor, desempata por id', () async {
      await insertFiado(db, 'z-1', 'b-1', 'c-1', occurredAt: at(10));
      await insertFiado(db, 'a-1', 'b-1', 'c-1', occurredAt: at(10));
      await insertPayment(db, 'm-1', 'b-1', 'c-1', occurredAt: at(10));

      expect(ids((await queries.historyOf('b-1', 'c-1'))!), [
        'a-1',
        'm-1',
        'z-1',
      ]);
    });

    test('el orden no depende del orden en que se insertaron', () async {
      await insertPayment(db, 'a-3', 'b-1', 'c-1', occurredAt: at(30));
      await insertFiado(db, 'f-1', 'b-1', 'c-1', occurredAt: at(10));
      await insertFiado(db, 'f-2', 'b-1', 'c-1', occurredAt: at(20));

      final first = ids((await queries.historyOf('b-1', 'c-1'))!);
      final second = ids((await queries.historyOf('b-1', 'c-1'))!);

      expect(first, ['f-1', 'f-2', 'a-3']);
      expect(second, first);
    });
  });

  group('aislamiento (principio 6)', () {
    test('solo trae los movimientos de ese cliente', () async {
      await insertClient(db, 'c-2', 'b-1', name: 'Beto');
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 5000);
      await insertFiado(db, 'f-2', 'b-1', 'c-2', total: 9000);
      await insertPayment(db, 'a-2', 'b-1', 'c-2', amount: 1000);

      final history = await queries.historyOf('b-1', 'c-1');

      expect(ids(history!), ['f-1']);
      expect(history.balance.amount, const Money(5000));
    });

    test('un cliente de otro negocio no se encuentra', () async {
      await insertClient(db, 'c-9', 'b-2', name: 'Intruso');
      await insertFiado(db, 'f-9', 'b-2', 'c-9', total: 5000);

      expect(await queries.historyOf('b-1', 'c-9'), isNull);
      expect(await queries.balanceOf('b-1', 'c-9'), isNull);
    });

    test('un cliente que no existe no se encuentra', () async {
      expect(await queries.historyOf('b-1', 'no-existe'), isNull);
      expect(await queries.balanceOf('b-1', 'no-existe'), isNull);
    });

    test('un cliente archivado también tiene historial y saldo', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 5000);
      await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
        const ClientsCompanion(archived: Value(true)),
      );

      final history = await queries.historyOf('b-1', 'c-1');

      expect(history!.client.archived, isTrue);
      expect(history.balance.amount, const Money(5000));
    });
  });

  group('saldos de todo el negocio', () {
    test('devuelve el saldo de cada cliente con movimientos', () async {
      await insertClient(db, 'c-2', 'b-1', name: 'Beto');
      await insertClient(db, 'c-3', 'b-1', name: 'Carla');
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 5000);
      await insertPayment(db, 'a-2', 'b-1', 'c-2', amount: 2000);

      final balances = await queries.balancesByClient('b-1');

      expect(balances['c-1'], const Balance(Money(5000)));
      expect(balances['c-2'], const Balance(Money(-2000)));
      expect(
        balances.containsKey('c-3'),
        isFalse,
        reason: 'sin movimientos: el llamador asume saldado',
      );
    });

    test('no mezcla clientes de otros negocios', () async {
      await insertClient(db, 'c-9', 'b-2', name: 'Intruso');
      await insertFiado(db, 'f-9', 'b-2', 'c-9', total: 9999);

      expect(await queries.balancesByClient('b-1'), isEmpty);
    });
  });
}
