import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/catalog/catalog_screen.dart';

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
  }) async {
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

  Future<void> chooseUnit(WidgetTester tester, String id) async {
    final chip = find.byKey(ValueKey('unit-$id'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('product-save')));
    await settle(tester);
  }

  Future<List<Product>> products(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.products).get()))!;

  String unitLabel(WidgetTester tester, String productId) => tester
      .widget<Text>(find.byKey(ValueKey('product-unit-$productId')))
      .data!;

  testWidgets('el formulario ofrece las 10 unidades y "unidad" por omisión', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('new-product')));
    await tester.pumpAndSettle();

    for (final unit in SaleUnit.values) {
      expect(find.byKey(ValueKey('unit-${unit.id}')), findsOne);
    }
    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((c) => c.selected);
    expect(selected, hasLength(1));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('unit-unit')))
          .selected,
      isTrue,
    );
  });

  testWidgets('crear un producto por libra lo guarda y lo muestra (RF-86)', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('new-product')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field-product-name')),
      'Carne',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-product-price')),
      '90',
    );
    await chooseUnit(tester, 'pound');
    await save(tester);

    final saved = (await products(tester)).single;
    expect(saved.unit, 'pound');
    expect(find.text('L 90.00'), findsOne);
    expect(unitLabel(tester, saved.id), 'por libra');
  });

  testWidgets('sin elegir unidad el producto queda por unidad', (tester) async {
    await pumpCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('new-product')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field-product-name')),
      'Sal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-product-price')),
      '10',
    );
    await save(tester);

    final saved = (await products(tester)).single;
    expect(saved.unit, 'unit');
    expect(unitLabel(tester, saved.id), 'por unidad');
  });

  testWidgets('la lista muestra la unidad de cada producto', (tester) async {
    await pumpCatalog(
      tester,
      seed: () async {
        await insertProductNamed(db, 'p-1', session.businessId, 'Huevos', 6000);
        await insertProductNamed(db, 'p-2', session.businessId, 'Leche', 3500);
        await (db.update(db.products)..where((p) => p.id.equals('p-1'))).write(
          const ProductsCompanion(unit: Value('dozen')),
        );
        await (db.update(db.products)..where((p) => p.id.equals('p-2'))).write(
          const ProductsCompanion(unit: Value('liter')),
        );
      },
    );

    expect(unitLabel(tester, 'p-1'), 'por docena');
    expect(unitLabel(tester, 'p-2'), 'por litro');
  });

  testWidgets('editar muestra la unidad actual y permite cambiarla', (
    tester,
  ) async {
    await pumpCatalog(
      tester,
      seed: () async {
        await insertProductNamed(db, 'p-1', session.businessId, 'Carne', 9000);
        await (db.update(db.products)..where((p) => p.id.equals('p-1'))).write(
          const ProductsCompanion(unit: Value('pound')),
        );
      },
    );

    await tester.tap(find.text('Carne'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('unit-pound')))
          .selected,
      isTrue,
    );

    await chooseUnit(tester, 'kilo');
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('unit-pound')))
          .selected,
      isFalse,
    );
    await save(tester);

    expect((await products(tester)).single.unit, 'kilo');
    expect(unitLabel(tester, 'p-1'), 'por kilo');
  });

  testWidgets('cambiar la unidad no altera los ítems ya fiados (RF-88)', (
    tester,
  ) async {
    await pumpCatalog(
      tester,
      seed: () async {
        await insertProductNamed(db, 'p-1', session.businessId, 'Carne', 9000);
        await (db.update(db.products)..where((p) => p.id.equals('p-1'))).write(
          const ProductsCompanion(unit: Value('pound')),
        );
        await insertClient(db, 'c-1', session.businessId);
        await insertFiado(db, 'f-1', session.businessId, 'c-1', total: 9000);
        await insertFiadoItem(
          db,
          'i-1',
          session.businessId,
          'f-1',
          productId: 'p-1',
          unitPrice: 9000,
          subtotal: 9000,
        );
        await (db.update(db.fiadoItems)..where((i) => i.id.equals('i-1')))
            .write(const FiadoItemsCompanion(unit: Value('pound')));
      },
    );

    await tester.tap(find.text('Carne'));
    await tester.pumpAndSettle();
    await chooseUnit(tester, 'kilo');
    await save(tester);

    final item = (await tester.runAsync(() => db.select(db.fiadoItems).get()))!
        .single;
    expect(item.unit, 'pound');
  });

  testWidgets('la etiqueta de unidad está en español', (tester) async {
    await pumpCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('new-product')));
    await tester.pumpAndSettle();

    expect(find.text(Strings.fieldUnit), findsOne);
    expect(find.text('Libra'), findsOne);
    expect(find.text('Docena'), findsOne);
    expect(find.text('Galón'), findsOne);
  });
}
