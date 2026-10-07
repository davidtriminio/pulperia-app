import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/product_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  late int idCounter;
  late ProductRepository repo;
  late String productId;

  setUp(() async {
    db = openDb();
    clock = DateTime.utc(2026, 10, 5, 10);
    idCounter = 0;
    repo = ProductRepository(
      db,
      newId: () => 'id-${++idCounter}',
      now: () => clock,
    );
    await insertBusiness(db, 'b-1');
    final created = await repo.create(
      businessId: 'b-1',
      userId: 'u-1',
      role: Role.owner,
      name: 'Aceite',
      price: const Money(2000),
      unit: SaleUnit.ounce,
    );
    productId = (created as ProductSaved).product.id;
    clock = DateTime.utc(2026, 10, 6, 9);
  });
  tearDown(() => db.close());

  Future<Product> row() => (db.select(
    db.products,
  )..where((p) => p.id.equals(productId))).getSingle();

  Future<ProductSaveResult> update({
    String name = 'Aceite',
    int price = 2000,
    SaleUnit? unit,
    Role role = Role.owner,
  }) => repo.update(
    businessId: 'b-1',
    userId: 'u-1',
    role: role,
    productId: productId,
    name: name,
    price: Money(price),
    unit: unit,
  );

  group('precio anterior al cambiar el precio (RF-90, D-24)', () {
    test('un producto nuevo no tiene precio anterior', () async {
      final product = await row();

      expect(product.previousPrice, isNull);
      expect(product.priceChangedAt, isNull);
    });

    test('cambiar el precio guarda el anterior y la fecha', () async {
      final result = await update(price: 2500);

      final product = await row();
      expect(product.price, 2500);
      expect(product.previousPrice, 2000);
      expect(product.priceChangedAt, DateTime.utc(2026, 10, 6, 9));
      expect(product.priceChangedAt!.isUtc, isTrue);
      expect((result as ProductSaved).product.previousPrice, 2000);
    });

    test('un segundo cambio reemplaza al anterior', () async {
      await update(price: 2500);
      clock = DateTime.utc(2026, 10, 7, 8);
      await update(price: 3000);

      final product = await row();
      expect(product.previousPrice, 2500);
      expect(product.priceChangedAt, DateTime.utc(2026, 10, 7, 8));
    });

    test('20, 25 y otra vez 20 deja 25 como anterior', () async {
      await update(price: 2500);
      clock = DateTime.utc(2026, 10, 7, 8);
      await update(price: 2000);

      final product = await row();
      expect(product.price, 2000);
      expect(product.previousPrice, 2500);
    });

    test('cambiar solo el nombre no toca el precio anterior', () async {
      await update(price: 2500);
      clock = DateTime.utc(2026, 10, 8, 8);
      await update(name: 'Aceite Mazola', price: 2500);

      final product = await row();
      expect(product.name, 'Aceite Mazola');
      expect(product.previousPrice, 2000);
      expect(product.priceChangedAt, DateTime.utc(2026, 10, 6, 9));
    });

    test('cambiar solo la unidad no toca el precio anterior', () async {
      await update(unit: SaleUnit.liter);

      final product = await row();
      expect(product.unit, 'liter');
      expect(product.previousPrice, isNull);
      expect(product.priceChangedAt, isNull);
    });

    test('guardar sin cambios no inventa un precio anterior', () async {
      await update();

      final product = await row();
      expect(product.previousPrice, isNull);
      expect(product.priceChangedAt, isNull);
    });

    test('un empleado también lo guarda al cambiar el precio', () async {
      await update(price: 2200, role: Role.employee);

      expect((await row()).previousPrice, 2000);
    });

    test('un precio inválido no cambia nada', () async {
      final result = await update(price: 0);

      expect(result, isA<ProductRejected>());
      final product = await row();
      expect(product.price, 2000);
      expect(product.previousPrice, isNull);
    });
  });

  group('lo que no debe cambiar', () {
    test(
      'los ítems de fiado ya guardados conservan su precio (RF-25)',
      () async {
        await insertClient(db, 'c-1', 'b-1');
        await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 2000);
        await insertFiadoItem(
          db,
          'i-1',
          'b-1',
          'f-1',
          productId: productId,
          description: 'Aceite',
          unitPrice: 2000,
          subtotal: 2000,
        );

        await update(price: 2500);

        final item = await db.select(db.fiadoItems).getSingle();
        expect(item.unitPrice, 2000);
        expect(item.subtotal, 2000);
      },
    );

    test('la operación de la cola conserva su forma', () async {
      await update(price: 2500);

      final op = (await (db.select(
        db.outboxOps,
      )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get()).last;
      expect(op.type, 'product.update');
      expect(jsonDecode(op.payload), {
        'name': 'Aceite',
        'price': 2500,
        'unit': 'ounce',
      });
    });

    test('la versión sube igual que antes', () async {
      await update(price: 2500);

      expect((await row()).version, 2);
    });
  });
}
