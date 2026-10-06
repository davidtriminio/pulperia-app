import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/product_repository.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProductRepository repo;
  var item = 0;

  setUp(() async {
    db = openDb();
    item = 0;
    repo = ProductRepository(db, newId: () => 'id', now: () => created);
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
    await insertClient(db, 'c-1', 'b-1');
    await insertClient(db, 'c-2', 'b-2');
  });
  tearDown(() => db.close());

  /// Crea un producto; [day] define su fecha de creación (más alto = más
  /// reciente).
  Future<void> product(
    String id,
    String name, {
    String business = 'b-1',
    int day = 1,
    bool archived = false,
  }) async {
    await insertProductNamed(db, id, business, name, 1000);
    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        archived: Value(archived),
        createdAt: Value(DateTime.utc(2026, 9, day)),
      ),
    );
  }

  /// Registra un fiado con una línea del producto, [times] veces.
  Future<void> fiadoOf(
    String productId, {
    int times = 1,
    String business = 'b-1',
    String client = 'c-1',
    bool annulled = false,
  }) async {
    for (var i = 0; i < times; i++) {
      item++;
      await insertFiado(
        db,
        'f-$item',
        business,
        client,
        annulledAt: annulled ? created : null,
        annulledBy: annulled ? 'u-1' : null,
      );
      await insertFiadoItem(
        db,
        'i-$item',
        business,
        'f-$item',
        productId: productId,
      );
    }
  }

  Future<List<String>> frequent({int limit = 8}) async => [
    for (final p in await repo.frequentProducts('b-1', limit: limit)) p.id,
  ];

  group('productos frecuentes (RF-26, RF-30)', () {
    test('ordena por veces fiado, de más a menos', () async {
      await product('p-a', 'Arroz');
      await product('p-b', 'Bolsa');
      await product('p-c', 'Carne');
      await fiadoOf('p-a', times: 1);
      await fiadoOf('p-b', times: 3);
      await fiadoOf('p-c', times: 2);

      expect(await frequent(), ['p-b', 'p-c', 'p-a']);
    });

    test('los empates se resuelven por nombre', () async {
      await product('p-z', 'Zanahoria');
      await product('p-a', 'arroz');
      await fiadoOf('p-z', times: 2);
      await fiadoOf('p-a', times: 2);

      expect(await frequent(), ['p-a', 'p-z']);
    });

    test('no cuenta los movimientos anulados', () async {
      await product('p-a', 'Arroz');
      await product('p-b', 'Bolsa');
      await fiadoOf('p-a', times: 5, annulled: true);
      await fiadoOf('p-b', times: 1);

      expect(await frequent(), ['p-b', 'p-a']);
    });

    test('excluye archivados y productos de otro negocio', () async {
      await product('p-a', 'Arroz', archived: true);
      await product('p-b', 'Bolsa');
      await product('p-x', 'Ajeno', business: 'b-2');
      await fiadoOf('p-a', times: 4);
      await fiadoOf('p-x', times: 9, business: 'b-2', client: 'c-2');

      expect(await frequent(), ['p-b']);
    });

    test('se completa con los más recientes si hay pocos fiados', () async {
      await product('p-a', 'Arroz', day: 1);
      await product('p-b', 'Bolsa', day: 5);
      await product('p-c', 'Carne', day: 3);
      await product('p-d', 'Dulce', day: 9);
      await fiadoOf('p-a');

      // Primero el fiado; luego el resto, del más reciente al más antiguo.
      expect(await frequent(), ['p-a', 'p-d', 'p-b', 'p-c']);
    });

    test('sin ningún fiado devuelve los más recientes', () async {
      await product('p-a', 'Arroz', day: 1);
      await product('p-b', 'Bolsa', day: 2);

      expect(await frequent(), ['p-b', 'p-a']);
    });

    test('un fiado sin producto (ítem libre) no cuenta', () async {
      await product('p-a', 'Arroz');
      await insertFiado(db, 'f-libre', 'b-1', 'c-1');
      await insertFiadoItem(db, 'i-libre', 'b-1', 'f-libre');

      expect(await frequent(), ['p-a']);
    });

    test('respeta el tope, 8 por omisión', () async {
      for (var i = 0; i < 12; i++) {
        await product('p-$i', 'Prod $i', day: i + 1);
      }

      expect((await frequent()).length, 8);
      expect((await frequent(limit: 3)).length, 3);
    });
  });
}
