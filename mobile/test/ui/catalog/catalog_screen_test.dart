import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/catalog/catalog_screen.dart';
import 'package:pulperia_mobile/ui/catalog/product_form_screen.dart';

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

  Future<void> pumpCatalog(
    WidgetTester tester, {
    Future<void> Function()? seed,
    Role role = Role.owner,
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await seed?.call();
    });
    final asRole = DevSession(
      businessId: session.businessId,
      businessName: session.businessName,
      userId: session.userId,
      role: role,
      amountMode: session.amountMode,
      quantityMode: session.quantityMode,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(asRole),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: CatalogScreen()),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> seedProducts() async {
    await insertProductNamed(db, 'p-2', session.businessId, 'azúcar', 1850);
    await insertProductNamed(db, 'p-1', session.businessId, 'Arroz', 2500);
  }

  Future<List<Product>> products(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.products).get()))!;

  Future<void> fillAndSave(
    WidgetTester tester, {
    String? name,
    String? price,
  }) async {
    if (name != null) {
      await tester.enterText(
        find.byKey(const ValueKey('field-product-name')),
        name,
      );
    }
    if (price != null) {
      await tester.enterText(
        find.byKey(const ValueKey('field-product-price')),
        price,
      );
    }
    await tester.tap(find.byKey(const ValueKey('product-save')));
    await settle(tester);
  }

  testWidgets('sin productos muestra el mensaje de catálogo vacío', (
    tester,
  ) async {
    await pumpCatalog(tester);

    expect(find.text(Strings.catalogEmpty), findsOne);
  });

  testWidgets('lista los productos con su precio, en orden alfabético', (
    tester,
  ) async {
    await pumpCatalog(tester, seed: seedProducts);

    expect(find.text('Arroz'), findsOne);
    expect(find.text('L 25.00'), findsOne);
    expect(find.text('azúcar'), findsOne);
    expect(find.text('L 18.50'), findsOne);
    expect(
      tester.getTopLeft(find.text('Arroz')).dy,
      lessThan(tester.getTopLeft(find.text('azúcar')).dy),
    );
  });

  testWidgets('no muestra archivados ni productos de otro negocio', (
    tester,
  ) async {
    await pumpCatalog(
      tester,
      seed: () async {
        await seedProducts();
        await insertBusiness(db, 'b-otro');
        await insertProductNamed(db, 'p-9', 'b-otro', 'Ajeno', 100);
        await (db.update(db.products)..where((p) => p.id.equals('p-2'))).write(
          const ProductsCompanion(archived: Value(true)),
        );
      },
    );

    expect(find.text('Arroz'), findsOne);
    expect(find.text('azúcar'), findsNothing);
    expect(find.text('Ajeno'), findsNothing);
  });

  testWidgets('crear un producto lo agrega a la lista (RF-24)', (tester) async {
    await pumpCatalog(tester);

    await tester.tap(find.byKey(const ValueKey('new-product')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductFormScreen), findsOne);
    await fillAndSave(tester, name: '  Frijoles ', price: '32.5');

    expect(find.byType(ProductFormScreen), findsNothing);
    expect(find.text('Frijoles'), findsOne);
    expect(find.text('L 32.50'), findsOne);
    final saved = (await products(tester)).single;
    expect(saved.name, 'Frijoles');
    expect(saved.price, 3250);
  });

  testWidgets('cambiar el precio no altera los ítems ya fiados (RF-25)', (
    tester,
  ) async {
    await pumpCatalog(
      tester,
      seed: () async {
        await seedProducts();
        await insertClient(db, 'c-1', session.businessId);
        await insertFiado(db, 'f-1', session.businessId, 'c-1', total: 2500);
        await insertFiadoItem(
          db,
          'i-1',
          session.businessId,
          'f-1',
          productId: 'p-1',
          unitPrice: 2500,
          subtotal: 2500,
        );
      },
    );

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    await fillAndSave(tester, price: '30');

    expect(find.text('L 30.00'), findsOne);
    final item = (await tester.runAsync(() => db.select(db.fiadoItems).get()))!
        .single;
    expect(item.unitPrice, 2500);
    expect(item.subtotal, 2500);
  });

  testWidgets('editar muestra los datos actuales del producto', (tester) async {
    await pumpCatalog(tester, seed: seedProducts);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    final name = tester.widget<TextField>(
      find.byKey(const ValueKey('field-product-name')),
    );
    final price = tester.widget<TextField>(
      find.byKey(const ValueKey('field-product-price')),
    );
    expect(name.controller!.text, 'Arroz');
    expect(price.controller!.text, '25.00');
  });

  testWidgets('archivar pide confirmación y retira el producto (RF-26)', (
    tester,
  ) async {
    await pumpCatalog(tester, seed: seedProducts);

    await tester.tap(find.byKey(const ValueKey('archive-p-1')));
    await tester.pumpAndSettle();
    expect(find.text(Strings.archiveProductTitle), findsOne);
    await tester.tap(find.byKey(const ValueKey('archive-confirm')));
    await settle(tester);

    expect(find.text('Arroz'), findsNothing);
    expect(find.text('azúcar'), findsOne);
    final archived = (await products(tester)).firstWhere((p) => p.id == 'p-1');
    expect(archived.archived, isTrue);
    expect(await products(tester), hasLength(2));
  });

  testWidgets('cancelar el archivado deja el producto', (tester) async {
    await pumpCatalog(tester, seed: seedProducts);

    await tester.tap(find.byKey(const ValueKey('archive-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('archive-cancel')));
    await settle(tester);

    expect(find.text('Arroz'), findsOne);
    expect(
      (await products(tester)).firstWhere((p) => p.id == 'p-1').archived,
      isFalse,
    );
  });

  testWidgets('no hay ninguna opción de borrar un producto (RF-27)', (
    tester,
  ) async {
    await pumpCatalog(tester, seed: seedProducts);

    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.textContaining('Eliminar'), findsNothing);
    expect(find.textContaining('Borrar'), findsNothing);
  });

  testWidgets('el empleado también administra el catálogo (RF-48)', (
    tester,
  ) async {
    await pumpCatalog(tester, seed: seedProducts, role: Role.employee);

    await tester.tap(find.byKey(const ValueKey('new-product')));
    await tester.pumpAndSettle();
    await fillAndSave(tester, name: 'Sal', price: '10');
    expect(find.text('Sal'), findsOne);

    await tester.tap(find.byKey(const ValueKey('archive-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('archive-confirm')));
    await settle(tester);
    expect(find.text('Arroz'), findsNothing);
  });

  group('validación del formulario', () {
    Future<void> openNew(WidgetTester tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.byKey(const ValueKey('new-product')));
      await tester.pumpAndSettle();
    }

    testWidgets('sin nombre indica que es obligatorio', (tester) async {
      await openNew(tester);
      await fillAndSave(tester, price: '10');

      expect(find.text(Strings.productNameRequired), findsOne);
      expect(await products(tester), isEmpty);
    });

    testWidgets('un nombre de solo espacios cuenta como vacío', (tester) async {
      await openNew(tester);
      await fillAndSave(tester, name: '   ', price: '10');

      expect(find.text(Strings.productNameRequired), findsOne);
    });

    testWidgets('sin precio pide indicarlo', (tester) async {
      await openNew(tester);
      await fillAndSave(tester, name: 'Sal');

      expect(find.text(Strings.priceRequired), findsOne);
      expect(await products(tester), isEmpty);
    });

    testWidgets('un precio de cero se rechaza', (tester) async {
      await openNew(tester);
      await fillAndSave(tester, name: 'Sal', price: '0');

      expect(find.text(Strings.amountNotPositive), findsOne);
      expect(await products(tester), isEmpty);
    });

    testWidgets('un precio con texto se rechaza', (tester) async {
      await openNew(tester);
      await fillAndSave(tester, name: 'Sal', price: 'abc');

      expect(find.text(Strings.amountInvalid), findsOne);
    });

    testWidgets('más de 2 decimales se rechaza', (tester) async {
      await openNew(tester);
      await fillAndSave(tester, name: 'Sal', price: '1.234');

      expect(find.text(Strings.amountTooManyDecimals), findsOne);
    });

    testWidgets('con montos enteros no se aceptan centavos (RF-36)', (
      tester,
    ) async {
      await pumpCatalog(
        tester,
        seed: () =>
            (db.update(db.businesses)
                  ..where((b) => b.id.equals(session.businessId)))
                .write(const BusinessesCompanion(amountMode: Value('integer'))),
      );
      await tester.tap(find.byKey(const ValueKey('new-product')));
      await tester.pumpAndSettle();

      await fillAndSave(tester, name: 'Sal', price: '10.50');

      expect(find.text(Strings.amountNotWhole), findsOne);
      expect(await products(tester), isEmpty);
    });
  });
}
