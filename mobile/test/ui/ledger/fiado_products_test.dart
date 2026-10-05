import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
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

  Future<void> openForm(WidgetTester tester, {bool withProducts = true}) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      if (withProducts) {
        await insertProductNamed(db, 'p-1', session.businessId, 'Arroz', 2500);
        await insertProductNamed(db, 'p-2', session.businessId, 'Azúcar', 1850);
        await insertProductNamed(db, 'p-3', session.businessId, 'Viejo', 999);
        await (db.update(db.products)..where((p) => p.id.equals('p-3'))).write(
          const ProductsCompanion(archived: Value(true)),
        );
        await insertBusiness(db, 'b-otro');
        await insertProductNamed(db, 'p-9', 'b-otro', 'Ajeno', 100);
      }
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

  Future<void> pickProduct(
    WidgetTester tester,
    int item,
    String productId,
  ) async {
    final button = find.byKey(ValueKey('pick-product-$item'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('product-option-$productId')));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

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

  Future<List<FiadoItem>> items(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!;

  testWidgets('el selector lista solo productos activos del negocio', (
    tester,
  ) async {
    await openForm(tester);

    await tester.tap(find.byKey(const ValueKey('pick-product-0')));
    await settle(tester);

    expect(find.byKey(const ValueKey('product-option-p-1')), findsOne);
    expect(find.byKey(const ValueKey('product-option-p-2')), findsOne);
    expect(find.text('Arroz'), findsOne);
    expect(find.text('L 25.00'), findsOne);
    expect(find.text('Viejo'), findsNothing);
    expect(find.text('Ajeno'), findsNothing);
  });

  testWidgets('elegir un producto propone su nombre y su precio (RF-30)', (
    tester,
  ) async {
    await openForm(tester);

    await pickProduct(tester, 0, 'p-1');

    expect(fieldText(tester, 'item-description-0'), 'Arroz');
    expect(fieldText(tester, 'item-price-0'), '25.00');
    expect(find.byKey(const ValueKey('item-product-0')), findsOne);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('item-subtotal-0'))).data,
      'L 25.00',
    );
  });

  testWidgets('el ítem guarda el producto, el nombre y el precio del momento', (
    tester,
  ) async {
    await openForm(tester);

    await pickProduct(tester, 0, 'p-1');
    await setField(tester, 'item-quantity-0', '2');
    await save(tester);

    final item = (await items(tester)).single;
    expect(item.productId, 'p-1');
    expect(item.description, 'Arroz');
    expect(item.quantity, 2000);
    expect(item.unitPrice, 2500);
    expect(item.subtotal, 5000);
  });

  testWidgets('cambiar el precio vale solo para ese ítem (RF-30)', (
    tester,
  ) async {
    await openForm(tester);

    await pickProduct(tester, 0, 'p-1');
    await setField(tester, 'item-price-0', '20');
    await save(tester);

    final item = (await items(tester)).single;
    expect(item.productId, 'p-1');
    expect(item.unitPrice, 2000);
    final product = (await tester.runAsync(
      () => (db.select(db.products)..where((p) => p.id.equals('p-1'))).get(),
    ))!.single;
    expect(product.price, 2500);
  });

  testWidgets('un ítem libre no pertenece al catálogo (RF-31)', (tester) async {
    await openForm(tester);

    await setField(tester, 'item-description-0', 'Un favor');
    await setField(tester, 'item-price-0', '7');
    await save(tester);

    final item = (await items(tester)).single;
    expect(item.productId, isNull);
    expect(item.description, 'Un favor');
  });

  testWidgets('se puede desvincular el producto y queda como ítem libre', (
    tester,
  ) async {
    await openForm(tester);
    await pickProduct(tester, 0, 'p-1');

    final unlink = find.byKey(const ValueKey('unlink-product-0'));
    await tester.ensureVisible(unlink);
    await tester.tap(unlink);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-product-0')), findsNothing);
    expect(fieldText(tester, 'item-description-0'), 'Arroz');
    await save(tester);

    final item = (await items(tester)).single;
    expect(item.productId, isNull);
    expect(item.description, 'Arroz');
    expect(item.unitPrice, 2500);
  });

  testWidgets('cada ítem elige su producto sin afectar a los demás', (
    tester,
  ) async {
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();

    await pickProduct(tester, 0, 'p-1');
    await pickProduct(tester, 1, 'p-2');

    expect(fieldText(tester, 'item-description-0'), 'Arroz');
    expect(fieldText(tester, 'item-description-1'), 'Azúcar');
    expect(fieldText(tester, 'item-price-1'), '18.50');
    await save(tester);
    final saved = await items(tester);
    expect(saved.map((i) => i.productId), unorderedEquals(['p-1', 'p-2']));
  });

  testWidgets('con el catálogo vacío el selector lo indica', (tester) async {
    await openForm(tester, withProducts: false);

    await tester.tap(find.byKey(const ValueKey('pick-product-0')));
    await settle(tester);

    expect(find.text(Strings.catalogEmpty), findsOne);
  });
}
