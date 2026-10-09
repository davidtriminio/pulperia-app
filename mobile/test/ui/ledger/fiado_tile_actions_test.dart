import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

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

  Future<void> pumpScreen(WidgetTester tester, {int products = 3}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      for (var i = 0; i < products; i++) {
        await insertProductNamed(
          db,
          'p-$i',
          session.businessId,
          'Prod $i',
          1000,
        );
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

  Finder key(String k) => find.byKey(ValueKey(k));
  String total(WidgetTester tester) =>
      tester.widget<Text>(key('fiado-total')).data!;
  String count(WidgetTester tester, String id) =>
      tester.widget<Text>(key('product-count-$id')).data!;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  group('tarjeta del producto con − cantidad + (T170)', () {
    testWidgets('sin agregar no muestra el botón −', (tester) async {
      await pumpScreen(tester);

      expect(key('product-minus-p-0'), findsNothing);
      expect(key('product-count-p-0'), findsNothing);
    });

    testWidgets('al agregar muestra − cantidad +', (tester) async {
      await pumpScreen(tester);

      await tap(tester, key('product-tile-p-0'));

      expect(key('product-minus-p-0'), findsOne);
      expect(key('product-plus-p-0'), findsOne);
      expect(count(tester, 'p-0'), '1');
    });

    testWidgets('+ suma 1 y − resta 1', (tester) async {
      await pumpScreen(tester);
      await tap(tester, key('product-tile-p-0'));

      await tap(tester, key('product-plus-p-0'));
      expect(count(tester, 'p-0'), '2');
      expect(total(tester), 'L 20.00');

      await tap(tester, key('product-minus-p-0'));
      expect(count(tester, 'p-0'), '1');
      expect(total(tester), 'L 10.00');
    });

    testWidgets('− con cantidad 1 quita el producto del carrito', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tap(tester, key('product-tile-p-0'));

      await tap(tester, key('product-minus-p-0'));

      expect(key('product-minus-p-0'), findsNothing);
      expect(total(tester), 'L 0.00');
      expect(find.text('Lo que se lleva'), findsOne);
      expect(find.text('Toca un producto para agregarlo'), findsOne);
    });

    testWidgets('un toque en el cuerpo de la tarjeta sigue agregando', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tap(tester, key('product-tile-p-0'));

      await tap(tester, key('product-tile-p-0'));

      expect(count(tester, 'p-0'), '2');
    });

    testWidgets('también funciona en la hoja "Ver todos"', (tester) async {
      await pumpScreen(tester, products: 10);
      await tap(tester, key('see-all'));
      final sheet = find.byKey(const ValueKey('all-sheet'));
      Finder inSheet(String k) => find.descendant(of: sheet, matching: key(k));

      await tap(tester, inSheet('product-tile-p-0'));
      await tap(tester, inSheet('product-plus-p-0'));
      expect(total(tester), 'L 20.00');

      await tap(tester, inSheet('product-minus-p-0'));
      await tap(tester, inSheet('product-minus-p-0'));
      expect(total(tester), 'L 0.00');
      expect(inSheet('product-minus-p-0'), findsNothing);
    });
  });

  group('borrar la línea entera del carrito (T171)', () {
    Finder deleteButton() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('line-delete-'),
    );

    testWidgets('con cantidad 1 no aparece', (tester) async {
      await pumpScreen(tester);
      await tap(tester, key('product-tile-p-0'));

      expect(deleteButton(), findsNothing);
    });

    testWidgets('con cantidad mayor que 1 aparece y borra de una vez', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tap(tester, key('product-tile-p-0'));
      await tap(tester, key('product-tile-p-0'));
      await tap(tester, key('product-tile-p-0'));
      expect(total(tester), 'L 30.00');
      expect(deleteButton(), findsOne);

      await tap(tester, deleteButton());

      expect(deleteButton(), findsNothing);
      expect(total(tester), 'L 0.00');
      expect(key('product-count-p-0'), findsNothing);
    });

    testWidgets('solo borra la línea tocada', (tester) async {
      await pumpScreen(tester);
      await tap(tester, key('product-tile-p-0'));
      await tap(tester, key('product-tile-p-0'));
      await tap(tester, key('product-tile-p-1'));

      await tap(tester, deleteButton());

      expect(total(tester), 'L 10.00');
      expect(key('product-count-p-1'), findsOne);
    });
  });
}
