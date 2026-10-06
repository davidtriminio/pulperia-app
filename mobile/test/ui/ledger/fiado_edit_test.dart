import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/input_limits.dart';
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
    String amountMode = 'two_decimals',
    String quantityMode = 'fractional',
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await (db.update(
        db.businesses,
      )..where((b) => b.id.equals(session.businessId))).write(
        BusinessesCompanion(
          amountMode: Value(amountMode),
          quantityMode: Value(quantityMode),
        ),
      );
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      await insertProductNamed(db, 'p-1', session.businessId, 'Arroz', 2500);
      await insertProductNamed(db, 'p-2', session.businessId, 'Carne', 9000);
      await (db.update(db.products)..where((p) => p.id.equals('p-2'))).write(
        const ProductsCompanion(unit: Value('pound')),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
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

  Future<void> addAndEdit(
    WidgetTester tester,
    String productId,
    int line,
  ) async {
    await tapKey(tester, 'product-tile-$productId');
    await tapKey(tester, 'line-edit-$line');
  }

  Future<void> setField(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tapKey(tester, 'fiado-save');
    await settle(tester);
  }

  Future<List<FiadoItem>> items(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!;

  group('abrir la edición de una línea (RF-30, RF-87)', () {
    testWidgets('tocar la línea abre la hoja con sus datos', (tester) async {
      await openScreen(tester);

      await addAndEdit(tester, 'p-2', 1);

      expect(find.byKey(const ValueKey('line-edit-sheet')), findsOne);
      expect(fieldText(tester, 'edit-description'), 'Carne');
      expect(fieldText(tester, 'edit-quantity'), '1');
      expect(fieldText(tester, 'edit-price'), '90.00');
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('unit-pound')))
            .selected,
        isTrue,
      );
    });

    testWidgets('cerrar sin guardar no cambia la línea', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);
      await setField(tester, 'edit-price', '1');

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('line-edit-sheet')), findsNothing);
      expect(text(tester, 'line-subtotal-1'), 'L 25.00');
    });
  });

  group('cambiar precio, cantidad y unidad', () {
    testWidgets('el precio vale solo para esa línea, no para el catálogo', (
      tester,
    ) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-price', '20');
      await tapKey(tester, 'line-save');

      expect(text(tester, 'line-subtotal-1'), 'L 20.00');
      await save(tester);
      final item = (await items(tester)).single;
      expect(item.unitPrice, 2000);
      expect(item.productId, 'p-1');
      final product = (await tester.runAsync(
        () => (db.select(db.products)..where((p) => p.id.equals('p-1'))).get(),
      ))!.single;
      expect(product.price, 2500);
    });

    testWidgets('con 2 decimales el subtotal se redondea al centavo', (
      tester,
    ) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-quantity', '0.333');
      await setField(tester, 'edit-price', '12.50');
      await tapKey(tester, 'line-save');

      expect(text(tester, 'line-subtotal-1'), 'L 4.16');
      expect(text(tester, 'fiado-total'), 'L 4.16');
    });

    testWidgets('con montos enteros redondea al lempira, la mitad sube', (
      tester,
    ) async {
      await openScreen(tester, amountMode: 'integer');
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-quantity', '0.5');
      await tapKey(tester, 'line-save');

      expect(text(tester, 'line-subtotal-1'), 'L 13');
    });

    testWidgets('la cantidad exacta se guarda en milésimas', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-2', 1);

      await setField(tester, 'edit-quantity', '2.5');
      await tapKey(tester, 'line-save');
      await save(tester);

      final item = (await items(tester)).single;
      expect(item.quantity, 2500);
      expect(item.subtotal, 22500);
      expect(item.unit, 'pound');
    });

    testWidgets(
      'cambiar la unidad vale solo para el ítem y no cambia el subtotal',
      (tester) async {
        await openScreen(tester);
        await addAndEdit(tester, 'p-2', 1);

        await tapKey(tester, 'unit-kilo');
        await tapKey(tester, 'line-save');

        expect(text(tester, 'line-subtotal-1'), 'L 90.00');
        await save(tester);
        expect((await items(tester)).single.unit, 'kilo');
        final product = (await tester.runAsync(
          () =>
              (db.select(db.products)..where((p) => p.id.equals('p-2'))).get(),
        ))!.single;
        expect(product.unit, 'pound');
      },
    );

    testWidgets('cambiar la descripción se guarda en el ítem', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-description', 'Arroz de primera');
      await tapKey(tester, 'line-save');
      await save(tester);

      expect((await items(tester)).single.description, 'Arroz de primera');
    });

    testWidgets('la línea muestra su precio y su unidad después de editar', (
      tester,
    ) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-price', '30');
      await tapKey(tester, 'unit-dozen');
      await tapKey(tester, 'line-save');

      expect(find.text('L 30.00 por docena'), findsOne);
    });
  });

  group('errores en español, por campo', () {
    Future<void> trySave(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('line-save')));
      await tester.pumpAndSettle();
    }

    testWidgets('cantidad en cero', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-quantity', '0');
      await trySave(tester);

      expect(find.text(Strings.quantityNotPositive), findsOne);
      expect(find.byKey(const ValueKey('line-edit-sheet')), findsOne);
    });

    testWidgets('cantidad que no es número', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-quantity', 'dos');
      await trySave(tester);

      expect(find.text(Strings.quantityInvalid), findsOne);
    });

    testWidgets('más de 3 decimales en la cantidad (RF-84)', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-quantity', '1.2345');
      await trySave(tester);

      expect(find.text(Strings.quantityTooManyDecimals), findsOne);
    });

    testWidgets('fracción con cantidades enteras (RF-35)', (tester) async {
      await openScreen(tester, quantityMode: 'integer');
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-quantity', '0.5');
      await trySave(tester);

      expect(find.text(Strings.quantityNotWhole), findsOne);
    });

    testWidgets('cantidad vacía', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-quantity', '');
      await trySave(tester);

      expect(find.text(Strings.quantityRequired), findsOne);
    });

    testWidgets('precio vacío', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-price', '');
      await trySave(tester);

      expect(find.text(Strings.priceRequired), findsOne);
    });

    testWidgets('precio en cero', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-price', '0');
      await trySave(tester);

      expect(find.text(Strings.amountNotPositive), findsOne);
    });

    testWidgets('centavos con montos enteros (RF-36)', (tester) async {
      await openScreen(tester, amountMode: 'integer');
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-price', '5.50');
      await trySave(tester);

      expect(find.text(Strings.amountNotWhole), findsOne);
    });

    testWidgets('corregir el error permite guardar', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);
      await setField(tester, 'edit-quantity', '0');
      await trySave(tester);
      expect(find.text(Strings.quantityNotPositive), findsOne);

      await setField(tester, 'edit-quantity', '3');
      await trySave(tester);

      expect(find.byKey(const ValueKey('line-edit-sheet')), findsNothing);
      expect(text(tester, 'line-qty-1'), '3');
    });

    testWidgets(
      'un subtotal que redondea a cero avisa en la línea y no guarda',
      (tester) async {
        await openScreen(tester);
        await addAndEdit(tester, 'p-1', 1);

        await setField(tester, 'edit-quantity', '0.001');
        await setField(tester, 'edit-price', '0.01');
        await trySave(tester);

        expect(find.byKey(const ValueKey('line-zero-1')), findsOne);
        expect(find.text(Strings.subtotalZero), findsWidgets);
        await save(tester);
        expect(find.byKey(const ValueKey('fiado-form-error')), findsOne);
        expect(
          (await tester.runAsync(() => db.select(db.fiados).get()))!,
          isEmpty,
        );
      },
    );
  });

  group('quitar y límites de largo', () {
    testWidgets('"Quitar" saca la línea del carrito', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await tapKey(tester, 'line-remove');

      expect(find.byKey(const ValueKey('cart-line-1')), findsNothing);
      expect(find.text(Strings.cartEmptyHint), findsOne);
    });

    testWidgets('descripción, cantidad y precio tienen su tope', (
      tester,
    ) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      await setField(tester, 'edit-description', 'a' * 300);
      await setField(tester, 'edit-quantity', '9' * 30);
      await setField(tester, 'edit-price', '9' * 30);

      expect(
        fieldText(tester, 'edit-description').length,
        InputLimits.itemDescription,
      );
      expect(fieldText(tester, 'edit-quantity').length, InputLimits.quantity);
      expect(fieldText(tester, 'edit-price').length, InputLimits.amount);
    });

    testWidgets('el selector ofrece las 10 unidades', (tester) async {
      await openScreen(tester);
      await addAndEdit(tester, 'p-1', 1);

      for (final unit in SaleUnit.values) {
        expect(find.byKey(ValueKey('unit-${unit.id}')), findsOne);
      }
    });
  });
}
