import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openDb();
    await insertBusiness(db, 'b-1');
    await insertClient(db, 'c-1', 'b-1');
  });
  tearDown(() => db.close());

  group('se guarda y se lee un registro de cada tabla (RF-51)', () {
    test('fiado sin ítems, solo con su total (RF-29)', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 5000);

      final fiado = await db.select(db.fiados).getSingle();
      expect(fiado.id, 'f-1');
      expect(fiado.businessId, 'b-1');
      expect(fiado.clientId, 'c-1');
      expect(fiado.total, 5000);
      expect(fiado.occurredAt.isAtSameMomentAs(created), isTrue);
      expect(fiado.createdBy, 'u-1');
      expect(fiado.annulledAt, isNull);
      expect(fiado.annulledBy, isNull);
      expect(fiado.serverSeq, isNull);
      expect(await db.select(db.fiadoItems).get(), isEmpty);
    });

    test('fiado con ítems, con sus relaciones (RF-28)', () async {
      await insertProduct(db, 'p-1', 'b-1');
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 4500);
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

      final items =
          await (db.select(db.fiadoItems)
                ..where((i) => i.fiadoId.equals('f-1'))
                ..orderBy([(i) => OrderingTerm.asc(i.id)]))
              .get();

      expect([for (final i in items) i.id], ['i-1', 'i-2']);
      expect(items[0].productId, 'p-1');
      expect(items[0].description, 'Arroz');
      expect(items[0].quantity, 2000);
      expect(items[0].unitPrice, 1500);
      expect(items[0].subtotal, 3000);
      expect(
        items[1].productId,
        isNull,
        reason: 'un ítem libre no tiene producto',
      );
      expect(items[1].description, 'Queso suelto');
      expect(items.fold<int>(0, (sum, i) => sum + i.subtotal), 4500);
    });

    test('abono', () async {
      await insertPayment(db, 'a-1', 'b-1', 'c-1', amount: 3000);

      final payment = await db.select(db.payments).getSingle();
      expect(payment.id, 'a-1');
      expect(payment.businessId, 'b-1');
      expect(payment.clientId, 'c-1');
      expect(payment.amount, 3000);
      expect(payment.occurredAt.isAtSameMomentAs(created), isTrue);
      expect(payment.createdBy, 'u-1');
      expect(payment.annulledAt, isNull);
      expect(payment.annulledBy, isNull);
      expect(payment.serverSeq, isNull);
    });

    test(
      'el orden de llegada al servidor se conserva cuando se conoce',
      () async {
        await insertFiado(db, 'f-1', 'b-1', 'c-1', serverSeq: 7);
        await insertPayment(db, 'a-1', 'b-1', 'c-1', serverSeq: 8);

        expect((await db.select(db.fiados).getSingle()).serverSeq, 7);
        expect((await db.select(db.payments).getSingle()).serverSeq, 8);
      },
    );
  });

  group('anulación (RF-43): el movimiento se conserva marcado', () {
    final annulled = DateTime.utc(2026, 10, 3, 9, 0, 0);

    test('un fiado anulado guarda quién y cuándo', () async {
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        annulledAt: annulled,
        annulledBy: 'u-2',
      );

      final fiado = await db.select(db.fiados).getSingle();
      expect(fiado.annulledAt!.isAtSameMomentAs(annulled), isTrue);
      expect(fiado.annulledBy, 'u-2');
    });

    test('un abono anulado guarda quién y cuándo', () async {
      await insertPayment(
        db,
        'a-1',
        'b-1',
        'c-1',
        annulledAt: annulled,
        annulledBy: 'u-2',
      );

      final payment = await db.select(db.payments).getSingle();
      expect(payment.annulledAt!.isAtSameMomentAs(annulled), isTrue);
      expect(payment.annulledBy, 'u-2');
    });

    test('no puede quedar anulado sin saber quién, ni al revés', () async {
      expect(
        insertFiado(db, 'f-1', 'b-1', 'c-1', annulledAt: annulled),
        throwsA(isA<Exception>()),
      );
      expect(
        insertFiado(db, 'f-2', 'b-1', 'c-1', annulledBy: 'u-2'),
        throwsA(isA<Exception>()),
      );
      expect(
        insertPayment(db, 'a-1', 'b-1', 'c-1', annulledAt: annulled),
        throwsA(isA<Exception>()),
      );
      expect(
        insertPayment(db, 'a-2', 'b-1', 'c-1', annulledBy: 'u-2'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('todo dato pertenece a un negocio (principio 6)', () {
    test('fiados, ítems y abonos tienen business_id', () {
      final tables = {
        'fiados': db.fiados.$columns,
        'fiado_items': db.fiadoItems.$columns,
        'payments': db.payments.$columns,
      };

      tables.forEach((name, columns) {
        expect(
          [for (final c in columns) c.name],
          contains('business_id'),
          reason: name,
        );
      });
    });

    test('un fiado de un cliente que no existe se rechaza', () async {
      expect(
        insertFiado(db, 'f-1', 'b-1', 'no-existe'),
        throwsA(isA<Exception>()),
      );
    });

    test('un abono de un cliente que no existe se rechaza', () async {
      expect(
        insertPayment(db, 'a-1', 'b-1', 'no-existe'),
        throwsA(isA<Exception>()),
      );
    });

    test('un ítem de un fiado que no existe se rechaza', () async {
      expect(
        insertFiadoItem(db, 'i-1', 'b-1', 'no-existe'),
        throwsA(isA<Exception>()),
      );
    });

    test('un ítem con un producto que no existe se rechaza', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1');

      expect(
        insertFiadoItem(db, 'i-1', 'b-1', 'f-1', productId: 'no-existe'),
        throwsA(isA<Exception>()),
      );
    });

    test('un fiado no puede apuntar a un cliente de otro negocio', () async {
      await insertBusiness(db, 'b-2');

      expect(insertFiado(db, 'f-1', 'b-2', 'c-1'), throwsA(isA<Exception>()));
    });

    test('un abono no puede apuntar a un cliente de otro negocio', () async {
      await insertBusiness(db, 'b-2');

      expect(insertPayment(db, 'a-1', 'b-2', 'c-1'), throwsA(isA<Exception>()));
    });

    test('un ítem no puede colgar de un fiado de otro negocio', () async {
      await insertBusiness(db, 'b-2');
      await insertFiado(db, 'f-1', 'b-1', 'c-1');

      expect(
        insertFiadoItem(db, 'i-1', 'b-2', 'f-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('un ítem no puede usar un producto de otro negocio', () async {
      await insertBusiness(db, 'b-2');
      await insertProduct(db, 'p-2', 'b-2');
      await insertFiado(db, 'f-1', 'b-1', 'c-1');

      expect(
        insertFiadoItem(db, 'i-1', 'b-1', 'f-1', productId: 'p-2'),
        throwsA(isA<Exception>()),
      );
    });

    test('los movimientos de dos negocios no se mezclan al filtrar', () async {
      await insertBusiness(db, 'b-2');
      await insertClient(db, 'c-2', 'b-2', name: 'Beto');
      await insertFiado(db, 'f-1', 'b-1', 'c-1');
      await insertFiado(db, 'f-2', 'b-2', 'c-2');
      await insertPayment(db, 'a-1', 'b-1', 'c-1');
      await insertPayment(db, 'a-2', 'b-2', 'c-2');

      final fiados = await (db.select(
        db.fiados,
      )..where((f) => f.businessId.equals('b-2'))).get();
      final payments = await (db.select(
        db.payments,
      )..where((p) => p.businessId.equals('b-1'))).get();

      expect([for (final f in fiados) f.id], ['f-2']);
      expect([for (final p in payments) p.id], ['a-1']);
    });
  });

  group('restricciones de valores', () {
    test('el total de un fiado debe ser positivo', () async {
      expect(
        insertFiado(db, 'f-0', 'b-1', 'c-1', total: 0),
        throwsA(isA<Exception>()),
      );
      expect(
        insertFiado(db, 'f-n', 'b-1', 'c-1', total: -100),
        throwsA(isA<Exception>()),
      );
    });

    test('el monto de un abono debe ser positivo', () async {
      expect(
        insertPayment(db, 'a-0', 'b-1', 'c-1', amount: 0),
        throwsA(isA<Exception>()),
      );
      expect(
        insertPayment(db, 'a-n', 'b-1', 'c-1', amount: -100),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'cantidad, precio y subtotal de un ítem deben ser positivos',
      () async {
        await insertFiado(db, 'f-1', 'b-1', 'c-1');

        expect(
          insertFiadoItem(db, 'i-1', 'b-1', 'f-1', quantity: 0),
          throwsA(isA<Exception>()),
        );
        expect(
          insertFiadoItem(db, 'i-2', 'b-1', 'f-1', unitPrice: 0),
          throwsA(isA<Exception>()),
        );
        expect(
          insertFiadoItem(db, 'i-3', 'b-1', 'f-1', subtotal: 0),
          throwsA(isA<Exception>()),
        );
        expect(
          insertFiadoItem(db, 'i-4', 'b-1', 'f-1', quantity: -1),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('no se repite el id de un fiado, un ítem ni un abono', () async {
      await insertFiado(db, 'f-1', 'b-1', 'c-1');
      await insertFiadoItem(db, 'i-1', 'b-1', 'f-1');
      await insertPayment(db, 'a-1', 'b-1', 'c-1');

      expect(insertFiado(db, 'f-1', 'b-1', 'c-1'), throwsA(isA<Exception>()));
      expect(
        insertFiadoItem(db, 'i-1', 'b-1', 'f-1'),
        throwsA(isA<Exception>()),
      );
      expect(insertPayment(db, 'a-1', 'b-1', 'c-1'), throwsA(isA<Exception>()));
    });
  });

  group('fechas en UTC', () {
    test('occurred_at y annulled_at se guardan como texto en UTC', () async {
      final local = DateTime.utc(2026, 1, 15, 3, 4, 5).toLocal();
      await insertFiado(
        db,
        'f-1',
        'b-1',
        'c-1',
        occurredAt: local,
        annulledAt: local,
        annulledBy: 'u-2',
      );
      await insertPayment(db, 'a-1', 'b-1', 'c-1', occurredAt: local);

      final fiado = await db
          .customSelect('SELECT occurred_at, annulled_at FROM fiados')
          .getSingle();
      final payment = await db
          .customSelect('SELECT occurred_at FROM payments')
          .getSingle();

      expect(fiado.read<String>('occurred_at'), '2026-01-15T03:04:05.000Z');
      expect(fiado.read<String>('annulled_at'), '2026-01-15T03:04:05.000Z');
      expect(payment.read<String>('occurred_at'), '2026-01-15T03:04:05.000Z');
    });
  });
}
