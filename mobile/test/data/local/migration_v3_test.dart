import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/db_fixtures.dart';

const _unitColumn =
    "unit TEXT NOT NULL DEFAULT 'unit' CHECK (unit IN ('unit', 'pound', "
    "'ounce', 'kilo', 'dozen', 'liter', 'gallon', 'box', 'bag', 'pack'))";

const _seed = [
  "INSERT INTO businesses VALUES ('b-1','Pulpería','integer','integer','2026-10-02T15:30:45.000Z')",
  "INSERT INTO clients (id, business_id, name, character_id, skin_id, background_id, created_by, created_at, updated_at) "
      "VALUES ('c-1','b-1','Ana','char-01','skin-1','bg-01','u-1','2026-10-02T15:30:45.000Z','2026-10-02T15:30:45.000Z')",
  "INSERT INTO products (id, business_id, name, price, created_by, created_at) "
      "VALUES ('p-1','b-1','Arroz',2500,'u-1','2026-10-02T15:30:45.000Z')",
  "INSERT INTO fiados (id, business_id, client_id, total, occurred_at, created_by) "
      "VALUES ('f-1','b-1','c-1',5000,'2026-10-02T15:30:45.000Z','u-1')",
  "INSERT INTO fiado_items (id, business_id, fiado_id, product_id, description, quantity, unit_price, subtotal) "
      "VALUES ('i-1','b-1','f-1','p-1','Arroz',2000,2500,5000)",
];

/// Una base en la versión 1 del esquema (la de antes de las unidades), con
/// datos, para que la app la migre.
AppDatabase openV1() {
  final schema = File('test/support/schema_v1.sql').readAsStringSync();
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(schema);
        _seed.forEach(raw.execute);
        raw.execute('PRAGMA user_version = 1');
      },
    ),
  );
}

/// Una base en la versión 2 (con la unidad de venta, sin el precio anterior),
/// con datos y un producto "por libra".
AppDatabase openV2() {
  final schema = File('test/support/schema_v1.sql').readAsStringSync();
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute(schema);
        raw.execute('ALTER TABLE products ADD COLUMN $_unitColumn');
        raw.execute('ALTER TABLE fiado_items ADD COLUMN $_unitColumn');
        _seed.forEach(raw.execute);
        raw.execute("UPDATE products SET unit = 'pound' WHERE id = 'p-1'");
        raw.execute('PRAGMA user_version = 2');
      },
    ),
  );
}

void main() {
  test('el esquema actual es la versión 3', () {
    final db = openDb();
    addTearDown(db.close);

    expect(db.schemaVersion, 3);
  });

  group('migración de la versión 2 a la 3 (RF-90, D-24)', () {
    late AppDatabase db;

    setUp(() => db = openV2());
    tearDown(() => db.close());

    test('conserva el producto con su unidad y precio', () async {
      final product = await db.select(db.products).getSingle();

      expect(product.id, 'p-1');
      expect(product.name, 'Arroz');
      expect(product.price, 2500);
      expect(product.unit, 'pound');
      expect(product.archived, isFalse);
    });

    test('deja el precio anterior y su fecha en nulo', () async {
      final product = await db.select(db.products).getSingle();

      expect(product.previousPrice, isNull);
      expect(product.priceChangedAt, isNull);
    });

    test('conserva fiados e ítems tal cual', () async {
      final fiado = await db.select(db.fiados).getSingle();
      final item = await db.select(db.fiadoItems).getSingle();

      expect(fiado.total, 5000);
      expect(item.unitPrice, 2500);
      expect(item.subtotal, 5000);
    });

    test('después se puede guardar el precio anterior y la fecha', () async {
      final changedAt = DateTime.utc(2026, 10, 5, 14, 30);
      await (db.update(db.products)..where((p) => p.id.equals('p-1'))).write(
        ProductsCompanion(
          price: const Value(3000),
          previousPrice: const Value(2500),
          priceChangedAt: Value(changedAt),
        ),
      );

      final product = await db.select(db.products).getSingle();
      expect(product.previousPrice, 2500);
      expect(product.priceChangedAt, changedAt);
      expect(product.priceChangedAt!.isUtc, isTrue);
    });
  });

  group('migración de la versión 1 a la 3', () {
    test('una base antigua llega al esquema actual sin perder datos', () async {
      final db = openV1();
      addTearDown(db.close);

      final product = await db.select(db.products).getSingle();
      expect(product.name, 'Arroz');
      expect(product.price, 2500);
      expect(product.unit, 'unit');
      expect(product.previousPrice, isNull);
      expect(product.priceChangedAt, isNull);
      final item = await db.select(db.fiadoItems).getSingle();
      expect(item.unit, 'unit');
    });
  });

  group('base nueva', () {
    late AppDatabase db;

    setUp(() async {
      db = openDb();
      await insertBusiness(db, 'b-1');
    });
    tearDown(() => db.close());

    test('un producto nuevo nace sin precio anterior', () async {
      await insertProductNamed(db, 'p-1', 'b-1', 'Arroz', 2500);

      final product = await db.select(db.products).getSingle();
      expect(product.previousPrice, isNull);
      expect(product.priceChangedAt, isNull);
    });

    test('el precio anterior debe ser mayor que cero', () async {
      await insertProductNamed(db, 'p-1', 'b-1', 'Arroz', 2500);

      expect(
        () => (db.update(db.products)..where((p) => p.id.equals('p-1'))).write(
          const ProductsCompanion(previousPrice: Value(0)),
        ),
        throwsA(anything),
      );
    });
  });
}
