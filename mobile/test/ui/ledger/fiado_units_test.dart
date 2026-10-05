import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/ui/ledger/fiado_form_screen.dart';

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

  Future<void> openForm(WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      await insertProductNamed(db, 'p-1', session.businessId, 'Carne', 9000);
      await insertProductNamed(db, 'p-2', session.businessId, 'Huevos', 6000);
      await (db.update(db.products)..where((p) => p.id.equals('p-1'))).write(
        const ProductsCompanion(unit: Value('pound')),
      );
      await (db.update(db.products)..where((p) => p.id.equals('p-2'))).write(
        const ProductsCompanion(unit: Value('dozen')),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: FiadoFormScreen(clientId: 'c-1'),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> pickProduct(WidgetTester tester, int item, String id) async {
    final button = find.byKey(ValueKey('pick-product-$item'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('product-option-$id')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseUnit(WidgetTester tester, int item, String unitId) async {
    final button = find.byKey(ValueKey('item-unit-$item'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('unit-option-$unitId')));
    await tester.pumpAndSettle();
  }

  Future<void> setField(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('fiado-save'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  String unitButton(WidgetTester tester, int item) =>
      tester.widget<Text>(find.byKey(ValueKey('item-unit-label-$item'))).data!;

  Future<List<FiadoItem>> items(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!;

  testWidgets('un ítem nuevo arranca con la unidad "unidad"', (tester) async {
    await openForm(tester);

    expect(unitButton(tester, 0), 'Unidad');
  });

  testWidgets('el selector ofrece las 10 unidades', (tester) async {
    await openForm(tester);

    await tester.tap(find.byKey(const ValueKey('item-unit-0')));
    await tester.pumpAndSettle();

    for (final unit in SaleUnit.values) {
      expect(find.byKey(ValueKey('unit-option-${unit.id}')), findsOne);
    }
  });

  testWidgets('elegir un producto propone la unidad del producto (RF-87)', (
    tester,
  ) async {
    await openForm(tester);

    await pickProduct(tester, 0, 'p-1');

    expect(unitButton(tester, 0), 'Libra');
  });

  testWidgets('el ítem guarda la unidad propuesta por el producto', (
    tester,
  ) async {
    await openForm(tester);

    await pickProduct(tester, 0, 'p-1');
    await setField(tester, 'item-quantity-0', '2.5');
    await save(tester);

    final item = (await items(tester)).single;
    expect(item.unit, 'pound');
    expect(item.productId, 'p-1');
    expect(item.quantity, 2500);
  });

  testWidgets('cambiar la unidad vale solo para ese ítem (RF-87)', (
    tester,
  ) async {
    await openForm(tester);

    await pickProduct(tester, 0, 'p-1');
    await chooseUnit(tester, 0, 'kilo');
    expect(unitButton(tester, 0), 'Kilo');
    await save(tester);

    final item = (await items(tester)).single;
    expect(item.unit, 'kilo');
    final product = (await tester.runAsync(
      () => (db.select(db.products)..where((p) => p.id.equals('p-1'))).get(),
    ))!.single;
    expect(product.unit, 'pound');
  });

  testWidgets('un ítem libre usa "unidad" y puede elegir otra', (tester) async {
    await openForm(tester);

    await setField(tester, 'item-description-0', 'Un tamal');
    await setField(tester, 'item-price-0', '15');
    await chooseUnit(tester, 0, 'dozen');
    await save(tester);

    final item = (await items(tester)).single;
    expect(item.productId, isNull);
    expect(item.unit, 'dozen');
  });

  testWidgets('un ítem libre sin tocar la unidad guarda "unidad"', (
    tester,
  ) async {
    await openForm(tester);

    await setField(tester, 'item-description-0', 'Favor');
    await setField(tester, 'item-price-0', '15');
    await save(tester);

    expect((await items(tester)).single.unit, 'unit');
  });

  testWidgets('la unidad no cambia el subtotal ni el total (RF-89)', (
    tester,
  ) async {
    await openForm(tester);
    await setField(tester, 'item-quantity-0', '2.5');
    await setField(tester, 'item-price-0', '25');
    String subtotal() => tester
        .widget<Text>(find.byKey(const ValueKey('item-subtotal-0')))
        .data!;
    String total() =>
        tester.widget<Text>(find.byKey(const ValueKey('fiado-total'))).data!;
    expect(subtotal(), 'L 62.50');

    await chooseUnit(tester, 0, 'pound');
    expect(subtotal(), 'L 62.50');
    await chooseUnit(tester, 0, 'dozen');
    expect(subtotal(), 'L 62.50');
    expect(total(), 'L 62.50');
  });

  testWidgets('quitar el vínculo con el catálogo conserva la unidad', (
    tester,
  ) async {
    await openForm(tester);
    await pickProduct(tester, 0, 'p-2');

    final unlink = find.byKey(const ValueKey('unlink-product-0'));
    await tester.ensureVisible(unlink);
    await tester.tap(unlink);
    await tester.pumpAndSettle();

    expect(unitButton(tester, 0), 'Docena');
  });

  testWidgets('cada ítem lleva su propia unidad', (tester) async {
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();

    await pickProduct(tester, 0, 'p-1');
    await pickProduct(tester, 1, 'p-2');
    await save(tester);

    final saved = {for (final i in await items(tester)) i.description: i.unit};
    expect(saved, {'Carne': 'pound', 'Huevos': 'dozen'});
  });

  testWidgets('la cantidad muestra la abreviatura de la unidad', (
    tester,
  ) async {
    await openForm(tester);

    await pickProduct(tester, 0, 'p-1');

    expect(find.text('lb'), findsOne);
  });
}
