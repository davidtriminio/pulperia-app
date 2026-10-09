import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/ui/catalog/catalog_screen.dart';
import 'package:pulperia_mobile/ui/catalog/product_form_screen.dart';
import 'package:pulperia_mobile/ui/theme.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DevSession session;

  setUp(() {
    db = openDb();
    session = devSessionFor(isRelease: false)!;
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    double width = 400,
    Future<void> Function()? seed,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await seed?.call();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(devSessionFor()!),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(body: CatalogScreen()),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> sample() async {
    Future<void> product(String id, String name, int price, {String? unit}) =>
        insertProductNamed(db, id, session.businessId, name, price);
    await product('p-1', 'Arroz', 2500);
    await product('p-2', 'Aceite', 4000);
    await product(
      'p-3',
      'Detergente en polvo para ropa de color extra largo para probar',
      123456789,
    );
    await (db.update(db.products)..where((p) => p.id.equals('p-2'))).write(
      ProductsCompanion(
        unit: const Value('ounce'),
        previousPrice: const Value(3500),
        priceChangedAt: Value(DateTime.utc(2026, 10, 5, 12)),
      ),
    );
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  group('tarjeta del catálogo (T182)', () {
    testWidgets('lleva nombre, unidad y precio', (tester) async {
      await pump(tester, seed: sample);

      expect(find.text('Arroz'), findsOne);
      expect(tester.widget<Text>(key('product-unit-p-1')).data, 'por unidad');
      expect(tester.widget<Text>(key('product-unit-p-2')).data, 'por onza');
      expect(tester.widget<Text>(key('product-price-p-1')).data, 'L 25.00');
    });

    testWidgets('con el estilo de las demás: esquinas 20 y sombra suave', (
      tester,
    ) async {
      await pump(tester, seed: sample);

      final box = tester.widget<DecoratedBox>(key('catalog-tile-p-1'));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('la unidad va en una píldora', (tester) async {
      await pump(tester, seed: sample);

      expect(key('product-unit-pill-p-1'), findsOne);
      expect(
        find.descendant(
          of: key('product-unit-pill-p-1'),
          matching: key('product-unit-p-1'),
        ),
        findsOne,
      );
    });

    testWidgets('el precio anterior sigue saliendo cuando existe', (
      tester,
    ) async {
      await pump(tester, seed: sample);

      expect(
        tester.widget<Text>(key('product-previous-p-2')).data,
        startsWith('Antes: L 35.00 · cambió el '),
      );
      expect(key('product-previous-p-1'), findsNothing);
    });

    testWidgets('todas tienen al menos la misma altura mínima', (tester) async {
      await pump(tester, seed: sample);

      double height(String id) =>
          tester.getSize(key('catalog-tile-$id')).height;
      expect(height('p-1'), greaterThanOrEqualTo(84));
      expect(height('p-2'), greaterThanOrEqualTo(84));
      // Con o sin precio anterior, la diferencia es solo esa línea.
      expect(height('p-2') - height('p-1'), lessThan(30));
    });

    testWidgets(
      'un nombre muy largo y un precio enorme no desbordan a 320 px',
      (tester) async {
        await pump(tester, width: 320, seed: sample);

        expect(tester.takeException(), isNull);
        expect(key('catalog-tile-p-3'), findsOne);
      },
    );

    testWidgets('el precio y archivar quedan pegados al borde derecho', (
      tester,
    ) async {
      // Pantalla ancha y precio corto: el hueco se vería si el precio no
      // estuviera pegado al borde.
      await pump(tester, width: 800, seed: sample);

      final tile = tester.getRect(key('catalog-tile-p-1'));
      final icon = tester.getRect(key('archive-p-1'));
      final price = tester.getRect(key('product-price-p-1'));
      // El icono llega casi al borde y el precio va justo a su lado, sin un
      // hueco vacío a la derecha.
      expect(tile.right - icon.right, lessThan(12));
      expect(icon.left - price.right, lessThan(24));
    });

    testWidgets('un toque abre la edición del producto', (tester) async {
      await pump(tester, seed: sample);

      await tester.tap(key('catalog-tile-p-1'));
      await settle(tester);

      expect(find.byType(ProductFormScreen), findsOne);
    });

    testWidgets('archivar sigue funcionando desde la tarjeta', (tester) async {
      await pump(tester, seed: sample);

      await tester.tap(key('archive-p-1'));
      await tester.pumpAndSettle();
      await tester.tap(key('archive-confirm'));
      await settle(tester);

      expect(find.text('Arroz'), findsNothing);
    });
  });
}
