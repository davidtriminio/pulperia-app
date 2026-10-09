import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/ui/catalog/catalog_screen.dart';
import 'package:pulperia_mobile/ui/format/date_format.dart';
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

  final changedAt = DateTime.utc(2026, 10, 5, 12);

  Future<void> pump(
    WidgetTester tester, {
    String amountMode = 'two_decimals',
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await (db.update(db.businesses)
            ..where((b) => b.id.equals(session.businessId)))
          .write(BusinessesCompanion(amountMode: Value(amountMode)));
      await insertProductNamed(db, 'p-1', session.businessId, 'Aceite', 2500);
      await insertProductNamed(db, 'p-2', session.businessId, 'Arroz', 3000);
      await (db.update(db.products)..where((p) => p.id.equals('p-1'))).write(
        ProductsCompanion(
          previousPrice: const Value(2000),
          priceChangedAt: Value(changedAt),
        ),
      );
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

  Finder key(String k) => find.byKey(ValueKey(k));

  group('precio anterior en el catálogo (RF-90)', () {
    testWidgets('un producto con cambio de precio muestra Antes y la fecha', (
      tester,
    ) async {
      await pump(tester);

      expect(
        tester.widget<Text>(key('product-previous-p-1')).data,
        'Antes: L 20.00 · cambió el ${formatDate(changedAt)}',
      );
      expect(formatDate(changedAt), '05/10/2026');
    });

    testWidgets('un producto sin cambios no lo muestra', (tester) async {
      await pump(tester);

      expect(key('product-previous-p-2'), findsNothing);
    });

    testWidgets('el formato respeta el modo de montos del negocio', (
      tester,
    ) async {
      await pump(tester, amountMode: 'integer');

      expect(
        tester.widget<Text>(key('product-previous-p-1')).data,
        startsWith('Antes: L 20 · '),
      );
    });

    testWidgets('el precio actual sigue visible junto al anterior', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('L 25.00'), findsOne);
      expect(find.text('L 30.00'), findsOne);
    });

    testWidgets(
      'al cambiar el precio desde el formulario aparece el anterior',
      (tester) async {
        await pump(tester);
        expect(key('product-previous-p-2'), findsNothing);

        await tester.tap(find.text('Arroz'));
        await settle(tester);
        await tester.enterText(key('field-product-price'), '35');
        await tester.tap(key('product-save'));
        await settle(tester);

        final text = tester.widget<Text>(key('product-previous-p-2')).data!;
        expect(text, startsWith('Antes: L 30.00 · cambió el '));
        expect(find.text('L 35.00'), findsOne);
      },
    );
  });

  group('formato de fecha corta', () {
    test('día, mes y año con ceros', () {
      expect(formatDate(DateTime.utc(2026, 1, 9, 12)), '09/01/2026');
    });
  });
}
