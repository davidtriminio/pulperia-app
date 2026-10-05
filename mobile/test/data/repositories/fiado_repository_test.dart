import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/data/repositories/fiado_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/ledger/fiado_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

import '../../support/db_fixtures.dart';

FiadoItemDraft item({
  String description = 'Arroz',
  String? productId,
  int quantityMilli = 1000,
  int unitPrice = 2500,
}) => FiadoItemDraft(
  description: description,
  productId: productId,
  quantity: Quantity(quantityMilli),
  unitPrice: Money(unitPrice),
);

void main() {
  late AppDatabase db;
  late DateTime clock;
  late int idCounter;
  late FiadoRepository repo;

  setUp(() async {
    db = openDb();
    clock = DateTime.utc(2026, 10, 3, 10);
    idCounter = 0;
    repo = FiadoRepository(
      db,
      newId: () => 'f-${++idCounter}',
      now: () => clock,
    );
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
    await insertClient(db, 'c-1', 'b-1');
    await insertClient(db, 'c-2', 'b-2');
  });
  tearDown(() => db.close());

  Future<List<OutboxOp>> outbox() => (db.select(
    db.outboxOps,
  )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

  Future<FiadoSaveResult> register(
    FiadoDraft draft, {
    String businessId = 'b-1',
    String clientId = 'c-1',
    String userId = 'u-1',
    Role role = Role.owner,
  }) => repo.create(
    businessId: businessId,
    userId: userId,
    role: role,
    clientId: clientId,
    draft: draft,
  );

  group('fiado con ítems (RF-28)', () {
    test('guarda el fiado con su total, cuándo ocurrió y quién lo registró (RF-49)', () async {
      final result = await register(
        FiadoWithItems([
          item(quantityMilli: 2000, unitPrice: 1500),
          item(description: 'Queso', quantityMilli: 500, unitPrice: 3000),
        ]),
        userId: 'u-7',
      );

      final saved = (result as FiadoSaved).fiado;
      final stored = await db.select(db.fiados).getSingle();
      expect(stored.id, saved.id);
      expect(stored.businessId, 'b-1');
      expect(stored.clientId, 'c-1');
      expect(stored.total, 4500);
      expect(stored.occurredAt.isAtSameMomentAs(clock), isTrue);
      expect(stored.createdBy, 'u-7');
      expect(stored.annulledAt, isNull);
      expect(stored.annulledBy, isNull);
      expect(stored.serverSeq, isNull);
    });

    test(
      'guarda cada ítem con su descripción, cantidad, precio y subtotal',
      () async {
        await insertProduct(db, 'p-1', 'b-1');
        final result = await register(
          FiadoWithItems([
            item(
              description: 'Arroz',
              productId: 'p-1',
              quantityMilli: 2000,
              unitPrice: 1500,
            ),
            item(
              description: 'Queso suelto',
              quantityMilli: 500,
              unitPrice: 3000,
            ),
          ]),
        );

        final saved = (result as FiadoSaved);
        final items = await (db.select(
          db.fiadoItems,
        )..orderBy([(i) => OrderingTerm.asc(i.description)])).get();
        expect(items.length, 2);
        expect({for (final i in items) i.fiadoId}, {saved.fiado.id});
        expect({for (final i in items) i.businessId}, {'b-1'});
        expect(items[0].description, 'Arroz');
        expect(items[0].productId, 'p-1');
        expect(items[0].quantity, 2000);
        expect(items[0].unitPrice, 1500);
        expect(items[0].subtotal, 3000);
        expect(items[1].description, 'Queso suelto');
        expect(items[1].productId, isNull);
        expect(items[1].quantity, 500);
        expect(items[1].unitPrice, 3000);
        expect(items[1].subtotal, 1500);
        expect(saved.items.length, 2);
      },
    );

    test(
      'el total guardado es la suma de los subtotales de sus ítems',
      () async {
        await register(
          FiadoWithItems([
            item(quantityMilli: 333, unitPrice: 1250),
            item(quantityMilli: 1500, unitPrice: 999),
            item(quantityMilli: 2000, unitPrice: 101),
          ]),
        );

        final items = await db.select(db.fiadoItems).get();
        final fiado = await db.select(db.fiados).getSingle();
        expect(items.fold<int>(0, (sum, i) => sum + i.subtotal), fiado.total);
      },
    );

    test(
      'con montos de 2 decimales el subtotal se redondea al centavo (RF-83)',
      () async {
        await register(
          FiadoWithItems([item(quantityMilli: 333, unitPrice: 1250)]),
        );

        expect((await db.select(db.fiadoItems).getSingle()).subtotal, 416);
        expect((await db.select(db.fiados).getSingle()).total, 416);
      },
    );

    test(
      'con montos enteros el subtotal se redondea al lempira (RF-34)',
      () async {
        await (db.update(db.businesses)..where((b) => b.id.equals('b-1')))
            .write(const BusinessesCompanion(amountMode: Value('integer')));

        await register(
          FiadoWithItems([item(quantityMilli: 250, unitPrice: 3000)]),
        );

        expect((await db.select(db.fiadoItems).getSingle()).subtotal, 800);
        expect((await db.select(db.fiados).getSingle()).total, 800);
      },
    );
  });

  group('ítems libres y precios (RF-30, RF-31)', () {
    test('un ítem que no es del catálogo se acepta', () async {
      final result = await register(
        FiadoWithItems([item(description: 'Fiado de la tienda de al lado')]),
      );

      expect(result, isA<FiadoSaved>());
      expect((await db.select(db.fiadoItems).getSingle()).productId, isNull);
    });

    test(
      'un ítem puede llevar un precio distinto al del catálogo sin cambiarlo',
      () async {
        await insertProduct(db, 'p-1', 'b-1', price: 2500);

        await register(
          FiadoWithItems([item(productId: 'p-1', unitPrice: 2000)]),
        );

        expect((await db.select(db.fiadoItems).getSingle()).unitPrice, 2000);
        expect((await db.select(db.products).getSingle()).price, 2500);
      },
    );

    test(
      'un producto que no existe en el negocio hace fallar todo y no deja nada',
      () async {
        await expectLater(
          register(FiadoWithItems([item(productId: 'no-existe')])),
          throwsA(isA<Exception>()),
        );

        expect(await db.select(db.fiados).get(), isEmpty);
        expect(await db.select(db.fiadoItems).get(), isEmpty);
        expect(await outbox(), isEmpty);
      },
    );

    test('un producto de otro negocio tampoco se puede usar', () async {
      await insertProduct(db, 'p-2', 'b-2');

      await expectLater(
        register(FiadoWithItems([item(productId: 'p-2')])),
        throwsA(isA<Exception>()),
      );

      expect(await db.select(db.fiados).get(), isEmpty);
    });
  });

  group('fiado solo con monto total (RF-29)', () {
    test('se guarda sin ítems', () async {
      final result = await register(const FiadoTotalOnly(Money(5000)));

      expect((result as FiadoSaved).items, isEmpty);
      expect((await db.select(db.fiados).getSingle()).total, 5000);
      expect(await db.select(db.fiadoItems).get(), isEmpty);
    });
  });

  group('se guarda junto con su operación en la cola (RF-51)', () {
    test(
      'encola un fiado.create pendiente con el contenido completo',
      () async {
        await insertProduct(db, 'p-1', 'b-1');
        final result = await register(
          FiadoWithItems([
            item(
              description: 'Arroz',
              productId: 'p-1',
              quantityMilli: 2000,
              unitPrice: 1500,
            ),
            item(description: 'Queso', quantityMilli: 500, unitPrice: 3000),
          ]),
        );

        final saved = (result as FiadoSaved);
        final ops = await outbox();
        expect(ops.length, 1);
        final op = ops.single;
        expect(op.type, 'fiado.create');
        expect(op.entityId, saved.fiado.id);
        expect(op.businessId, 'b-1');
        expect(op.status, 'pending');
        expect(op.baseVersion, isNull);
        expect(op.createdAt.isAtSameMomentAs(clock), isTrue);

        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        expect(payload['clientId'], 'c-1');
        expect(payload['total'], 4500);
        expect(payload['occurredAt'], '2026-10-03T10:00:00.000Z');
        final items = (payload['items'] as List).cast<Map<String, dynamic>>();
        expect(
          [for (final i in items) i['id']],
          [for (final i in saved.items) i.id],
        );
        expect(items[0], {
          'id': saved.items[0].id,
          'productId': 'p-1',
          'description': 'Arroz',
          'quantity': 2000,
          'unit': 'unit',
          'unitPrice': 1500,
          'subtotal': 3000,
        });
        expect(items[1]['productId'], isNull);
        expect(items[1]['subtotal'], 1500);
      },
    );

    test('un fiado solo con total viaja con la lista de ítems vacía', () async {
      await register(const FiadoTotalOnly(Money(5000)));

      final payload =
          jsonDecode((await outbox()).single.payload) as Map<String, dynamic>;
      expect(payload['total'], 5000);
      expect(payload['items'], isEmpty);
    });

    test('si falla el encolado, no queda ni el fiado ni sus ítems', () async {
      // El id de la operación será 'f-2' (el fiado usa 'f-1').
      await insertOutboxOp(db, 'f-2', 'b-1');

      await expectLater(
        register(FiadoWithItems([item(), item(description: 'Otro')])),
        throwsA(isA<Exception>()),
      );

      expect(await db.select(db.fiados).get(), isEmpty);
      expect(await db.select(db.fiadoItems).get(), isEmpty);
      expect(
        (await outbox()).length,
        1,
        reason: 'solo la operación preexistente',
      );
    });

    test('varios fiados se encolan en orden, cada uno con su fecha', () async {
      await register(const FiadoTotalOnly(Money(1000)));
      clock = clock.add(const Duration(minutes: 5));
      await register(const FiadoTotalOnly(Money(2000)));

      final ops = await outbox();
      expect(
        [for (final o in ops) (jsonDecode(o.payload) as Map)['total']],
        [1000, 2000],
      );
      expect(ops[1].createdAt.isAfter(ops[0].createdAt), isTrue);
      final fiados = await db.select(db.fiados).get();
      expect({for (final f in fiados) f.id}.length, 2);
    });
  });

  group('lo que no se acepta', () {
    test('un fiado vacío no escribe nada y dice por qué (RF-33)', () async {
      final result = await register(const FiadoWithItems([]));

      expect(
        [for (final i in (result as FiadoRejected).issues) i.code],
        ['fiado_empty'],
      );
      expect(await db.select(db.fiados).get(), isEmpty);
      expect(await outbox(), isEmpty);
    });

    test(
      'valores en cero o negativos se rechazan campo por campo (RF-32)',
      () async {
        final result = await register(
          FiadoWithItems([item(quantityMilli: 0), item(unitPrice: -5)]),
        );

        final issues = (result as FiadoRejected).issues;
        expect(
          [for (final i in issues) (i.itemIndex, i.field, i.code)],
          [
            (0, FiadoField.quantity, 'quantity_not_positive'),
            (1, FiadoField.unitPrice, 'amount_not_positive'),
          ],
        );
        expect(await db.select(db.fiados).get(), isEmpty);
        expect(await outbox(), isEmpty);
      },
    );

    test(
      'con montos enteros, un precio con centavos se rechaza (RF-36)',
      () async {
        await (db.update(db.businesses)..where((b) => b.id.equals('b-1')))
            .write(const BusinessesCompanion(amountMode: Value('integer')));

        final result = await register(FiadoWithItems([item(unitPrice: 1250)]));

        expect(
          (result as FiadoRejected).issues.single.code,
          'amount_not_whole',
        );
      },
    );

    test('con cantidades enteras, una fracción se rechaza (RF-35)', () async {
      await (db.update(db.businesses)..where((b) => b.id.equals('b-1'))).write(
        const BusinessesCompanion(quantityMode: Value('integer')),
      );

      final result = await register(
        FiadoWithItems([item(quantityMilli: 2500)]),
      );

      expect(
        (result as FiadoRejected).issues.single.code,
        'quantity_not_whole',
      );
    });

    test(
      'un cliente que no existe, o de otro negocio, no se encuentra',
      () async {
        expect(
          await register(
            const FiadoTotalOnly(Money(100)),
            clientId: 'no-existe',
          ),
          isA<FiadoClientNotFound>(),
        );
        expect(
          await register(const FiadoTotalOnly(Money(100)), clientId: 'c-2'),
          isA<FiadoClientNotFound>(),
        );
        expect(await db.select(db.fiados).get(), isEmpty);
        expect(await outbox(), isEmpty);
      },
    );

    test('un negocio que no existe lanza error y no deja nada', () async {
      await expectLater(
        register(const FiadoTotalOnly(Money(100)), businessId: 'no-existe'),
        throwsA(isA<Object>()),
      );

      expect(await db.select(db.fiados).get(), isEmpty);
    });
  });

  group('permisos y efecto en el saldo', () {
    test('el empleado también registra fiados (RF-48)', () async {
      final result = await register(
        const FiadoTotalOnly(Money(3000)),
        userId: 'u-2',
        role: Role.employee,
      );

      expect(result, isA<FiadoSaved>());
      expect((await db.select(db.fiados).getSingle()).createdBy, 'u-2');
    });

    test('el saldo del cliente refleja el fiado nuevo', () async {
      final clients = ClientRepository(
        db,
        newId: () => 'x-${++idCounter}',
        now: () => clock,
      );
      await register(
        FiadoWithItems([item(quantityMilli: 2000, unitPrice: 1500)]),
      );
      await register(const FiadoTotalOnly(Money(1000)));

      final active = await clients.activeClients('b-1');

      expect(active.single.balance, const Balance(Money(4000)));
    });
  });
}
