import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/product_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  late int idCounter;
  late ProductRepository repo;

  setUp(() async {
    db = openDb();
    clock = DateTime.utc(2026, 10, 3, 10);
    idCounter = 0;
    repo = ProductRepository(
      db,
      newId: () => 'id-${++idCounter}',
      now: () => clock,
    );
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
  });
  tearDown(() => db.close());

  Future<List<OutboxOp>> outbox() => (db.select(
    db.outboxOps,
  )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

  Future<Product> productRow(String id) =>
      (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();

  Future<String> createProduct(
    String name,
    int price, {
    String businessId = 'b-1',
    Role role = Role.owner,
  }) async {
    final result = await repo.create(
      businessId: businessId,
      userId: 'u-1',
      role: role,
      name: name,
      price: Money(price),
    );
    return (result as ProductSaved).product.id;
  }

  Future<void> advance() async => clock = clock.add(const Duration(hours: 1));

  group('crear un producto (RF-24)', () {
    test('guarda nombre, precio, versión 1 y autoría', () async {
      final result = await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        name: '  Arroz 1 lb ',
        price: const Money(2500),
      );

      final saved = (result as ProductSaved).product;
      final stored = await db.select(db.products).getSingle();
      expect(stored.id, saved.id);
      expect(stored.businessId, 'b-1');
      expect(stored.name, 'Arroz 1 lb');
      expect(stored.price, 2500);
      expect(stored.archived, isFalse);
      expect(stored.version, 1);
      expect(stored.createdBy, 'u-1');
      expect(stored.createdAt.isAtSameMomentAs(clock), isTrue);
    });

    test('encola un product.create pendiente', () async {
      final id = await createProduct('Arroz', 2500);

      final ops = await outbox();
      expect(ops.length, 1);
      expect(ops.single.type, 'product.create');
      expect(ops.single.entityId, id);
      expect(ops.single.businessId, 'b-1');
      expect(ops.single.status, 'pending');
      expect(ops.single.baseVersion, isNull);
      expect(ops.single.createdAt.isAtSameMomentAs(clock), isTrue);
      expect(jsonDecode(ops.single.payload), {
        'name': 'Arroz',
        'price': 2500,
        'unit': 'unit',
      });
    });

    test('el empleado también puede administrar el catálogo (RF-48)', () async {
      final result = await repo.create(
        businessId: 'b-1',
        userId: 'u-2',
        role: Role.employee,
        name: 'Frijoles',
        price: const Money(1800),
      );

      expect(result, isA<ProductSaved>());
    });

    test(
      'un producto inválido no escribe ni encola, y dice qué falla',
      () async {
        final result = await repo.create(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          name: '  ',
          price: const Money(0),
        );

        expect(
          [for (final i in (result as ProductRejected).issues) i.code],
          ['product_name_required', 'amount_not_positive'],
        );
        expect(await db.select(db.products).get(), isEmpty);
        expect(await outbox(), isEmpty);
      },
    );

    test(
      'con montos enteros, un precio con centavos se rechaza (RF-36)',
      () async {
        await (db.update(db.businesses)..where((b) => b.id.equals('b-1')))
            .write(const BusinessesCompanion(amountMode: Value('integer')));

        final result = await repo.create(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          name: 'Arroz',
          price: const Money(1250),
        );

        expect(
          (result as ProductRejected).issues.single.code,
          'amount_not_whole',
        );
      },
    );

    test('si falla el encolado, no queda el producto guardado', () async {
      await insertOutboxOp(db, 'id-2', 'b-1');

      await expectLater(
        repo.create(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          name: 'Arroz',
          price: const Money(2500),
        ),
        throwsA(isA<Exception>()),
      );

      expect(await db.select(db.products).get(), isEmpty);
    });

    test('un negocio que no existe lanza error y no deja nada', () async {
      await expectLater(
        repo.create(
          businessId: 'no-existe',
          userId: 'u-1',
          role: Role.owner,
          name: 'Arroz',
          price: const Money(2500),
        ),
        throwsA(isA<Object>()),
      );

      expect(await db.select(db.products).get(), isEmpty);
      expect(await outbox(), isEmpty);
    });
  });

  group('cambiar el precio o el nombre (RF-25)', () {
    late String productId;

    setUp(() async {
      productId = await createProduct('Arroz', 2500);
      await advance();
    });

    test(
      'cambia el precio, sube la versión y encola un product.update',
      () async {
        final result = await repo.update(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          productId: productId,
          name: 'Arroz',
          price: const Money(2800),
        );

        expect(result, isA<ProductSaved>());
        final stored = await productRow(productId);
        expect(stored.price, 2800);
        expect(stored.version, 2);

        final op = (await outbox()).last;
        expect(op.type, 'product.update');
        expect(op.entityId, productId);
        expect(op.status, 'pending');
        expect(op.baseVersion, 1);
        expect(jsonDecode(op.payload), {
          'name': 'Arroz',
          'price': 2800,
          'unit': 'unit',
        });
      },
    );

    test('también cambia el nombre', () async {
      await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
        name: 'Arroz extra',
        price: const Money(2500),
      );

      expect((await productRow(productId)).name, 'Arroz extra');
    });

    test(
      'RF-25: cambiar el precio no altera los ítems de fiado ya registrados',
      () async {
        await insertClient(db, 'c-1', 'b-1');
        await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 5000);
        await insertFiadoItem(
          db,
          'i-1',
          'b-1',
          'f-1',
          productId: productId,
          description: 'Arroz',
          quantity: 2000,
          unitPrice: 2500,
          subtotal: 5000,
        );

        await repo.update(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          productId: productId,
          name: 'Arroz premium',
          price: const Money(9999),
        );

        final item = await db.select(db.fiadoItems).getSingle();
        expect(item.unitPrice, 2500);
        expect(item.subtotal, 5000);
        expect(item.description, 'Arroz');
        expect(item.quantity, 2000);
        expect((await db.select(db.fiados).getSingle()).total, 5000);
      },
    );

    test('ediciones seguidas encadenan las versiones base', () async {
      for (final price in [2600, 2700, 2800]) {
        await repo.update(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          productId: productId,
          name: 'Arroz',
          price: Money(price),
        );
      }

      final updates = (await outbox()).where((o) => o.type == 'product.update');
      expect([for (final o in updates) o.baseVersion], [1, 2, 3]);
    });

    test('un precio inválido no cambia nada ni encola', () async {
      final opsBefore = (await outbox()).length;

      final result = await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
        name: 'Arroz',
        price: const Money(-5),
      );

      expect(
        (result as ProductRejected).issues.single.code,
        'amount_not_positive',
      );
      expect((await productRow(productId)).price, 2500);
      expect((await outbox()).length, opsBefore);
    });

    test(
      'un producto que no existe, o de otro negocio, no se encuentra',
      () async {
        expect(
          await repo.update(
            businessId: 'b-1',
            userId: 'u-1',
            role: Role.owner,
            productId: 'no-existe',
            name: 'X',
            price: const Money(100),
          ),
          isA<ProductNotFound>(),
        );
        expect(
          await repo.update(
            businessId: 'b-2',
            userId: 'u-1',
            role: Role.owner,
            productId: productId,
            name: 'Intruso',
            price: const Money(100),
          ),
          isA<ProductNotFound>(),
        );
        expect((await productRow(productId)).name, 'Arroz');
      },
    );

    test('si falla el encolado, el producto queda como estaba', () async {
      await insertOutboxOp(db, 'id-${idCounter + 1}', 'b-1');

      await expectLater(
        repo.update(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          productId: productId,
          name: 'Arroz',
          price: const Money(9000),
        ),
        throwsA(isA<Exception>()),
      );

      expect((await productRow(productId)).price, 2500);
      expect((await productRow(productId)).version, 1);
    });
  });

  group('archivar un producto, sin borrarlo (RF-26, RF-27)', () {
    late String productId;

    setUp(() async {
      productId = await createProduct('Arroz', 2500);
      await advance();
    });

    test(
      'queda archivado, con versión nueva, y encola un product.archive',
      () async {
        final result = await repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          productId: productId,
        );

        expect((result as ProductSaved).product.archived, isTrue);
        final stored = await productRow(productId);
        expect(stored.archived, isTrue);
        expect(stored.version, 2);

        final op = (await outbox()).last;
        expect(op.type, 'product.archive');
        expect(op.entityId, productId);
        expect(op.baseVersion, 1);
        expect(op.payload, '{}');
      },
    );

    test('RF-27: el producto no se borra: sigue en la tabla con su nombre y precio', () async {
      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
      );

      final stored = await db.select(db.products).getSingle();
      expect(stored.id, productId);
      expect(stored.name, 'Arroz');
      expect(stored.price, 2500);
    });

    test('RF-26: los ítems ya registrados conservan su descripción, su precio y su producto', () async {
      await insertClient(db, 'c-1', 'b-1');
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 5000);
      await insertFiadoItem(
        db,
        'i-1',
        'b-1',
        'f-1',
        productId: productId,
        description: 'Arroz',
        quantity: 2000,
        unitPrice: 2500,
        subtotal: 5000,
      );

      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
      );

      final item = await db.select(db.fiadoItems).getSingle();
      expect(item.productId, productId);
      expect(item.description, 'Arroz');
      expect(item.unitPrice, 2500);
      expect(item.subtotal, 5000);
    });

    test('un archivado deja de ofrecerse al fiar y aparece en la lista de archivados', () async {
      final other = await createProduct('Frijoles', 1800);
      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
      );

      expect([for (final p in await repo.activeProducts('b-1')) p.id], [other]);
      expect(
        [for (final p in await repo.archivedProducts('b-1')) p.id],
        [productId],
      );
    });

    test('archivar uno ya archivado no cambia nada ni encola', () async {
      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
      );
      final opsBefore = (await outbox()).length;

      final result = await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
      );

      expect((result as ProductSaved).product.archived, isTrue);
      expect((await productRow(productId)).version, 2);
      expect((await outbox()).length, opsBefore);
    });

    test(
      'un producto que no existe, o de otro negocio, no se encuentra',
      () async {
        expect(
          await repo.archive(
            businessId: 'b-1',
            userId: 'u-1',
            role: Role.owner,
            productId: 'no-existe',
          ),
          isA<ProductNotFound>(),
        );
        expect(
          await repo.archive(
            businessId: 'b-2',
            userId: 'u-1',
            role: Role.owner,
            productId: productId,
          ),
          isA<ProductNotFound>(),
        );
        expect((await productRow(productId)).archived, isFalse);
      },
    );

    test('si falla el encolado, no queda archivado', () async {
      await insertOutboxOp(db, 'id-${idCounter + 1}', 'b-1');

      await expectLater(
        repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          productId: productId,
        ),
        throwsA(isA<Exception>()),
      );

      expect((await productRow(productId)).archived, isFalse);
    });

    test('el empleado también puede archivar productos (RF-48)', () async {
      final result = await repo.archive(
        businessId: 'b-1',
        userId: 'u-2',
        role: Role.employee,
        productId: productId,
      );

      expect(result, isA<ProductSaved>());
    });
  });

  group('listas del catálogo', () {
    test('van en orden alfabético sin distinguir mayúsculas, y solo del negocio pedido', () async {
      await createProduct('frijoles', 1800);
      await createProduct('Arroz', 2500);
      await createProduct('Café', 4500);
      await createProduct('Intruso', 100, businessId: 'b-2');

      final names = [for (final p in await repo.activeProducts('b-1')) p.name];

      expect(names, ['Arroz', 'Café', 'frijoles']);
    });

    test('un negocio sin productos tiene listas vacías', () async {
      expect(await repo.activeProducts('b-1'), isEmpty);
      expect(await repo.archivedProducts('b-1'), isEmpty);
    });
  });
}
