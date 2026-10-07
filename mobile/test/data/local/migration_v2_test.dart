import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';

import '../../support/db_fixtures.dart';

/// Abre una base que está en la versión 1 del esquema (la de antes de las
/// unidades de venta), con datos, y deja que la app la migre.
AppDatabase openV1WithData() {
  final schema = File('test/support/schema_v1.sql').readAsStringSync();
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(schema);
        raw.execute(
          "INSERT INTO businesses VALUES ('b-1','Pulpería','integer','integer','2026-10-02T15:30:45.000Z')",
        );
        raw.execute(
          "INSERT INTO clients (id, business_id, name, character_id, skin_id, background_id, created_by, created_at, updated_at) "
          "VALUES ('c-1','b-1','Ana','char-01','skin-1','bg-01','u-1','2026-10-02T15:30:45.000Z','2026-10-02T15:30:45.000Z')",
        );
        raw.execute(
          "INSERT INTO products (id, business_id, name, price, created_by, created_at) "
          "VALUES ('p-1','b-1','Arroz',2500,'u-1','2026-10-02T15:30:45.000Z')",
        );
        raw.execute(
          "INSERT INTO fiados (id, business_id, client_id, total, occurred_at, created_by) "
          "VALUES ('f-1','b-1','c-1',5000,'2026-10-02T15:30:45.000Z','u-1')",
        );
        raw.execute(
          "INSERT INTO fiado_items (id, business_id, fiado_id, product_id, description, quantity, unit_price, subtotal) "
          "VALUES ('i-1','b-1','f-1','p-1','Arroz',2000,2500,5000)",
        );
        raw.execute('PRAGMA user_version = 1');
      },
    ),
  );
}

void main() {
  test('el esquema es al menos la versión 2', () {
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(2));
  });

  group('migración de la versión 1 a la 2 (RF-86, RF-88)', () {
    late AppDatabase db;

    setUp(() => db = openV1WithData());
    tearDown(() => db.close());

    test('conserva los productos y les pone la unidad por omisión', () async {
      final product = await db.select(db.products).getSingle();

      expect(product.id, 'p-1');
      expect(product.name, 'Arroz');
      expect(product.price, 2500);
      expect(product.unit, 'unit');
    });

    test(
      'conserva los ítems de fiado y les pone la unidad por omisión',
      () async {
        final item = await db.select(db.fiadoItems).getSingle();

        expect(item.id, 'i-1');
        expect(item.description, 'Arroz');
        expect(item.quantity, 2000);
        expect(item.unitPrice, 2500);
        expect(item.subtotal, 5000);
        expect(item.unit, 'unit');
      },
    );

    test('no pierde el resto de los datos', () async {
      expect(await db.select(db.businesses).get(), hasLength(1));
      expect(await db.select(db.clients).get(), hasLength(1));
      final fiado = await db.select(db.fiados).getSingle();
      expect(fiado.total, 5000);
    });

    test('tras migrar se pueden guardar productos con otra unidad', () async {
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              id: 'p-2',
              businessId: 'b-1',
              name: 'Carne',
              price: 9000,
              unit: const Value('pound'),
              createdBy: 'u-1',
              createdAt: created,
            ),
          );

      final carne = await (db.select(
        db.products,
      )..where((p) => p.id.equals('p-2'))).getSingle();
      expect(carne.unit, 'pound');
    });
  });

  group('base nueva', () {
    late AppDatabase db;

    setUp(() async {
      db = openDb();
      await insertBusiness(db, 'b-1');
    });
    tearDown(() => db.close());

    test('un producto sin unidad indicada queda con la de omisión', () async {
      await insertProduct(db, 'p-1', 'b-1');

      expect((await db.select(db.products).getSingle()).unit, 'unit');
    });

    test('un ítem sin unidad indicada queda con la de omisión', () async {
      await insertClient(db, 'c-1', 'b-1');
      await insertFiado(db, 'f-1', 'b-1', 'c-1');
      await insertFiadoItem(db, 'i-1', 'b-1', 'f-1');

      expect((await db.select(db.fiadoItems).getSingle()).unit, 'unit');
    });

    test('la base acepta todas las unidades de SaleUnit y solo esas', () async {
      var n = 0;
      for (final unit in SaleUnit.values) {
        await db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                id: 'p-${n++}',
                businessId: 'b-1',
                name: 'P',
                price: 100,
                unit: Value(unit.id),
                createdBy: 'u-1',
                createdAt: created,
              ),
            );
      }

      expect(await db.select(db.products).get(), hasLength(10));
    });

    test('la base rechaza una unidad fuera de la lista en productos', () async {
      expect(
        () => db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                id: 'p-9',
                businessId: 'b-1',
                name: 'X',
                price: 100,
                unit: const Value('stone'),
                createdBy: 'u-1',
                createdAt: created,
              ),
            ),
        throwsA(anything),
      );
    });

    test('la base rechaza una unidad fuera de la lista en ítems', () async {
      await insertClient(db, 'c-1', 'b-1');
      await insertFiado(db, 'f-1', 'b-1', 'c-1');

      expect(
        () => db
            .into(db.fiadoItems)
            .insert(
              FiadoItemsCompanion.insert(
                id: 'i-9',
                businessId: 'b-1',
                fiadoId: 'f-1',
                description: 'X',
                quantity: 1000,
                unit: const Value('stone'),
                unitPrice: 100,
                subtotal: 100,
              ),
            ),
        throwsA(anything),
      );
    });
  });
}
