import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/ledger/fiado_form_screen.dart';
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

  Future<void> openScreen(
    WidgetTester tester, {
    bool withProducts = true,
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      if (withProducts) {
        await insertProductNamed(db, 'p-1', session.businessId, 'Arroz', 2500);
      }
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
          home: const FiadoFormScreen(clientId: 'c-1'),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> setField(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> save(WidgetTester tester) async {
    await tapKey(tester, 'fiado-save');
    await settle(tester);
  }

  Future<List<FiadoItem>> items(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!;

  testWidgets('el botón "Otro" está aunque el catálogo esté vacío', (
    tester,
  ) async {
    await openScreen(tester, withProducts: false);

    expect(find.byKey(const ValueKey('add-free')), findsOne);
    expect(find.text(Strings.catalogEmpty), findsOne);
  });

  testWidgets('agrega una línea sin producto y abre su edición (RF-31)', (
    tester,
  ) async {
    await openScreen(tester);

    await tapKey(tester, 'add-free');

    expect(find.byKey(const ValueKey('cart-line-1')), findsOne);
    expect(find.byKey(const ValueKey('line-edit-sheet')), findsOne);
    expect(fieldText(tester, 'edit-description'), '');
    expect(fieldText(tester, 'edit-quantity'), '1');
    expect(fieldText(tester, 'edit-price'), '');
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('unit-unit')))
          .selected,
      isTrue,
    );
  });

  testWidgets('con descripción, precio y unidad se guarda sin producto', (
    tester,
  ) async {
    await openScreen(tester);
    await tapKey(tester, 'add-free');

    await setField(tester, 'edit-description', 'Un tamal');
    await setField(tester, 'edit-price', '15');
    await tapKey(tester, 'unit-dozen');
    await tapKey(tester, 'line-save');

    expect(find.text('Un tamal'), findsOne);
    expect(text(tester, 'line-subtotal-1'), 'L 15.00');
    expect(text(tester, 'fiado-total'), 'L 15.00');
    await save(tester);
    final item = (await items(tester)).single;
    expect(item.productId, isNull);
    expect(item.description, 'Un tamal');
    expect(item.unit, 'dozen');
    expect(item.unitPrice, 1500);
  });

  testWidgets('sin tocar la unidad queda en "unidad"', (tester) async {
    await openScreen(tester);
    await tapKey(tester, 'add-free');

    await setField(tester, 'edit-price', '8');
    await tapKey(tester, 'line-save');
    await save(tester);

    expect((await items(tester)).single.unit, 'unit');
  });

  testWidgets('la descripción no es obligatoria', (tester) async {
    await openScreen(tester);
    await tapKey(tester, 'add-free');

    await setField(tester, 'edit-price', '8');
    await tapKey(tester, 'line-save');

    expect(find.text(Strings.freeItem), findsOne);
    await save(tester);
    expect((await items(tester)).single.description, '');
  });

  testWidgets('el precio sí es obligatorio al guardar la edición', (
    tester,
  ) async {
    await openScreen(tester);
    await tapKey(tester, 'add-free');

    await tester.tap(find.byKey(const ValueKey('line-save')));
    await tester.pumpAndSettle();

    expect(find.text(Strings.priceRequired), findsOne);
    expect(find.byKey(const ValueKey('line-edit-sheet')), findsOne);
  });

  testWidgets('cerrar la edición sin precio deja la línea marcada', (
    tester,
  ) async {
    await openScreen(tester);
    await tapKey(tester, 'add-free');

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('line-missing-price-1')), findsOne);
    expect(text(tester, 'fiado-total'), 'L 0.00');
  });

  testWidgets('con una línea sin precio no se puede registrar', (tester) async {
    await openScreen(tester);
    await tapKey(tester, 'product-tile-p-1');
    await tapKey(tester, 'add-free');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await save(tester);

    expect(find.text(Strings.fiadoMissingPrice), findsOne);
    expect((await tester.runAsync(() => db.select(db.fiados).get()))!, isEmpty);
  });

  testWidgets('se mezcla con productos del catálogo', (tester) async {
    await openScreen(tester);
    await tapKey(tester, 'product-tile-p-1');
    await tapKey(tester, 'add-free');
    await setField(tester, 'edit-description', 'Favor');
    await setField(tester, 'edit-price', '5');
    await tapKey(tester, 'line-save');

    await save(tester);

    final saved = {for (final i in await items(tester)) i.description: i};
    expect(saved['Arroz']!.productId, 'p-1');
    expect(saved['Favor']!.productId, isNull);
    expect(
      (await tester.runAsync(() => db.select(db.fiados).get()))!.single.total,
      3000,
    );
  });

  testWidgets('dos ítems libres son líneas independientes', (tester) async {
    await openScreen(tester);
    await tapKey(tester, 'add-free');
    await setField(tester, 'edit-price', '5');
    await tapKey(tester, 'line-save');
    await tapKey(tester, 'add-free');
    await setField(tester, 'edit-price', '7');
    await tapKey(tester, 'line-save');

    expect(find.byKey(const ValueKey('cart-line-1')), findsOne);
    expect(find.byKey(const ValueKey('cart-line-2')), findsOne);
    expect(text(tester, 'fiado-total'), 'L 12.00');
  });
}
