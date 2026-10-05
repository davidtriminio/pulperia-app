import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/fiado_repository.dart';
import 'package:pulperia_mobile/data/repositories/product_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/domain/ledger/fiado_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

import '../../support/db_fixtures.dart';

FiadoItemDraft item({
  String description = 'Arroz',
  String? productId,
  int quantityMilli = 1000,
  int unitPrice = 2500,
  SaleUnit? unit,
}) => unit == null
    ? FiadoItemDraft(
        description: description,
        productId: productId,
        quantity: Quantity(quantityMilli),
        unitPrice: Money(unitPrice),
      )
    : FiadoItemDraft(
        description: description,
        productId: productId,
        quantity: Quantity(quantityMilli),
        unitPrice: Money(unitPrice),
        unit: unit,
      );

void main() {
  late AppDatabase db;
  late int idCounter;
  late ProductRepository products;
  late FiadoRepository fiados;

  setUp(() async {
    db = openDb();
    idCounter = 0;
    final clock = DateTime.utc(2026, 10, 3, 10);
    products = ProductRepository(
      db,
      newId: () => 'id-${++idCounter}',
      now: () => clock,
    );
    fiados = FiadoRepository(
      db,
      newId: () => 'f-${++idCounter}',
      now: () => clock,
    );
    await insertBusiness(db, 'b-1');
    await insertClient(db, 'c-1', 'b-1');
  });
  tearDown(() => db.close());

  Future<List<OutboxOp>> outbox() => (db.select(
    db.outboxOps,
  )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

  Future<Product> productRow(String id) =>
      (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();

  Future<String> createProduct(String name, int price, {SaleUnit? unit}) async {
    final result = unit == null
        ? await products.create(
            businessId: 'b-1',
            userId: 'u-1',
            role: Role.owner,
            name: name,
            price: Money(price),
          )
        : await products.create(
            businessId: 'b-1',
            userId: 'u-1',
            role: Role.owner,
            name: name,
            price: Money(price),
            unit: unit,
          );
    return (result as ProductSaved).product.id;
  }

  group('productos con unidad (RF-86)', () {
    test('un producto nuevo sin unidad indicada usa "unidad"', () async {
      final id = await createProduct('Arroz', 2500);

      expect((await productRow(id)).unit, 'unit');
    });

    test('guarda la unidad que se le indica', () async {
      final id = await createProduct('Carne', 9000, unit: SaleUnit.pound);

      expect((await productRow(id)).unit, 'pound');
    });

    test('la operación de la cola lleva la unidad al crear', () async {
      await createProduct('Huevos', 6000, unit: SaleUnit.dozen);

      final payload =
          jsonDecode((await outbox()).single.payload) as Map<String, dynamic>;
      expect(payload['unit'], 'dozen');
      expect(payload['name'], 'Huevos');
      expect(payload['price'], 6000);
    });

    test('cambiar la unidad actualiza el producto y la cola', () async {
      final id = await createProduct('Carne', 9000, unit: SaleUnit.pound);

      await products.update(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: id,
        name: 'Carne',
        price: const Money(9000),
        unit: SaleUnit.kilo,
      );

      expect((await productRow(id)).unit, 'kilo');
      final ops = await outbox();
      final payload = jsonDecode(ops.last.payload) as Map<String, dynamic>;
      expect(ops.last.type, 'product.update');
      expect(payload['unit'], 'kilo');
    });

    test('editar sin indicar la unidad conserva la que tenía', () async {
      final id = await createProduct('Carne', 9000, unit: SaleUnit.pound);

      await products.update(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: id,
        name: 'Carne molida',
        price: const Money(9500),
      );

      final row = await productRow(id);
      expect(row.unit, 'pound');
      final payload =
          jsonDecode((await outbox()).last.payload) as Map<String, dynamic>;
      expect(payload['unit'], 'pound');
    });

    test('un id de unidad fuera de la lista no se puede construir', () {
      expect(() => SaleUnit.fromId('stone'), throwsArgumentError);
    });
  });

  group('ítems de fiado con unidad (RF-87, RF-88)', () {
    Future<FiadoSaved> register(List<FiadoItemDraft> items) async {
      final result = await fiados.create(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: 'c-1',
        draft: FiadoWithItems(items),
      );
      return result as FiadoSaved;
    }

    test('guarda la unidad de cada ítem', () async {
      final saved = await register([
        item(description: 'Carne', unit: SaleUnit.pound, quantityMilli: 2500),
        item(description: 'Huevos', unit: SaleUnit.dozen),
      ]);

      final units = {for (final i in saved.items) i.description: i.unit};
      expect(units, {'Carne': 'pound', 'Huevos': 'dozen'});
    });

    test('un ítem sin unidad indicada (libre) usa "unidad"', () async {
      final saved = await register([item(description: 'Favor')]);

      expect(saved.items.single.unit, 'unit');
      expect(saved.items.single.productId, isNull);
    });

    test('la unidad no cambia el subtotal ni el total (RF-89)', () async {
      final base = await register([item(quantityMilli: 2500, unitPrice: 2500)]);
      final withUnit = await register([
        item(quantityMilli: 2500, unitPrice: 2500, unit: SaleUnit.pound),
      ]);

      expect(withUnit.items.single.subtotal, base.items.single.subtotal);
      expect(withUnit.fiado.total, base.fiado.total);
      expect(withUnit.items.single.subtotal, 6250);
    });

    test('la operación de la cola lleva la unidad de cada ítem', () async {
      await register([
        item(description: 'Carne', unit: SaleUnit.pound),
        item(description: 'Sal'),
      ]);

      final payload =
          jsonDecode((await outbox()).single.payload) as Map<String, dynamic>;
      final items = (payload['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(items.map((i) => i['unit']), ['pound', 'unit']);
    });

    test(
      'cambiar la unidad del producto no altera ítems ya guardados',
      () async {
        final productId = await createProduct(
          'Carne',
          9000,
          unit: SaleUnit.pound,
        );
        await register([
          item(
            description: 'Carne',
            productId: productId,
            unitPrice: 9000,
            unit: SaleUnit.pound,
          ),
        ]);

        await products.update(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          productId: productId,
          name: 'Carne',
          price: const Money(9500),
          unit: SaleUnit.kilo,
        );

        final stored = await db.select(db.fiadoItems).getSingle();
        expect(stored.unit, 'pound');
        expect(stored.unitPrice, 9000);
      },
    );

    test('archivar el producto tampoco altera la unidad del ítem', () async {
      final productId = await createProduct(
        'Huevos',
        6000,
        unit: SaleUnit.dozen,
      );
      await register([
        item(
          description: 'Huevos',
          productId: productId,
          unitPrice: 6000,
          unit: SaleUnit.dozen,
        ),
      ]);

      await products.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        productId: productId,
      );

      expect((await db.select(db.fiadoItems).getSingle()).unit, 'dozen');
    });

    test(
      'un ítem puede usar una unidad distinta a la de su producto',
      () async {
        final productId = await createProduct(
          'Huevos',
          6000,
          unit: SaleUnit.dozen,
        );

        final saved = await register([
          item(
            description: 'Huevos',
            productId: productId,
            unitPrice: 500,
            unit: SaleUnit.unit,
          ),
        ]);

        expect(saved.items.single.unit, 'unit');
        expect((await productRow(productId)).unit, 'dozen');
      },
    );
  });
}
