import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/ui/catalog/product_form_screen.dart';
import 'package:pulperia_mobile/ui/theme.dart';
import 'package:pulperia_mobile/ui/widgets/confirm_dialog.dart';

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

  Future<void> product(
    String id,
    String name,
    int price, {
    String unit = 'ounce',
    bool archived = false,
  }) async {
    await insertProductNamed(db, id, session.businessId, name, price);
    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(unit: Value(unit), archived: Value(archived)),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? seed,
    Product? editing,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await seed?.call();
    });
    final existing = editing == null
        ? null
        : await tester.runAsync(
            () => (db.select(
              db.products,
            )..where((p) => p.id.equals(editing.id))).getSingle(),
          );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ProductFormScreen(existing: existing),
        ),
      ),
    );
    await settle(tester);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> fill(
    WidgetTester tester, {
    String? name,
    String? price,
    SaleUnit? unit,
  }) async {
    if (name != null) {
      await tester.enterText(key('field-product-name'), name);
    }
    if (price != null) {
      await tester.enterText(key('field-product-price'), price);
    }
    if (unit != null) {
      final chip = key('unit-${unit.id}');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
    }
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(key('product-save'));
    await tester.tap(key('product-save'));
    await settle(tester);
  }

  Future<List<Product>> products(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.products).get()))!;

  Future<Product> row(WidgetTester tester, String id) async =>
      (await products(tester)).firstWhere((p) => p.id == id);

  group('aviso al crear un producto repetido (RF-91)', () {
    testWidgets('mismo nombre y unidad avisa y no guarda todavía', (
      tester,
    ) async {
      await pump(tester, seed: () => product('p-1', 'Aceite', 2500));

      await fill(tester, name: ' aceite ', price: '30', unit: SaleUnit.ounce);
      await save(tester);

      expect(find.byType(ConfirmDialog), findsOne);
      expect(find.text('Ya existe un producto igual'), findsOne);
      expect(find.textContaining('L 25.00'), findsOne);
      expect((await products(tester)).length, 1);
    });

    testWidgets('"Crear de todos modos" guarda el segundo producto', (
      tester,
    ) async {
      await pump(tester, seed: () => product('p-1', 'Aceite', 2500));
      await fill(tester, name: 'Aceite', price: '30', unit: SaleUnit.ounce);
      await save(tester);

      await tester.tap(key('duplicate-confirm'));
      await settle(tester);

      final all = await products(tester);
      expect(all.length, 2);
      expect(all.map((p) => p.price), containsAll([2500, 3000]));
    });

    testWidgets('"Cancelar" vuelve al formulario sin guardar', (tester) async {
      await pump(tester, seed: () => product('p-1', 'Aceite', 2500));
      await fill(tester, name: 'Aceite', price: '30', unit: SaleUnit.ounce);
      await save(tester);

      await tester.tap(key('duplicate-cancel'));
      await settle(tester);

      expect(find.byType(ConfirmDialog), findsNothing);
      expect(key('product-save'), findsOne);
      expect((await products(tester)).length, 1);
    });

    testWidgets('"Cambiar el precio del existente" abre ese producto', (
      tester,
    ) async {
      await pump(tester, seed: () => product('p-1', 'Aceite', 2500));
      await fill(tester, name: 'Aceite', price: '30', unit: SaleUnit.ounce);
      await save(tester);

      await tester.tap(key('duplicate-open-existing'));
      await settle(tester);

      // Se abre la edición del producto existente, con sus datos.
      expect(find.byType(ConfirmDialog), findsNothing);
      expect(find.text('Editar producto'), findsOne);
      expect(
        tester.widget<TextField>(key('field-product-price')).controller!.text,
        '25.00',
      );
      expect((await products(tester)).length, 1);

      // Y guardar ahí cambia el precio del existente, sin crear otro.
      await fill(tester, price: '28');
      await save(tester);
      final all = await products(tester);
      expect(all.length, 1);
      expect(all.single.price, 2800);
    });

    testWidgets('otra unidad no avisa y guarda', (tester) async {
      await pump(tester, seed: () => product('p-1', 'Aceite', 2500));

      await fill(tester, name: 'Aceite', price: '90', unit: SaleUnit.liter);
      await save(tester);

      expect(find.byType(ConfirmDialog), findsNothing);
      expect((await products(tester)).length, 2);
    });

    testWidgets('un archivado igual no avisa', (tester) async {
      await pump(
        tester,
        seed: () => product('p-1', 'Aceite', 2500, archived: true),
      );

      await fill(tester, name: 'Aceite', price: '30', unit: SaleUnit.ounce);
      await save(tester);

      expect(find.byType(ConfirmDialog), findsNothing);
      expect((await products(tester)).length, 2);
    });

    testWidgets('un nombre distinto no avisa', (tester) async {
      await pump(tester, seed: () => product('p-1', 'Aceite', 2500));

      await fill(
        tester,
        name: 'Aceite Mazola',
        price: '30',
        unit: SaleUnit.ounce,
      );
      await save(tester);

      expect(find.byType(ConfirmDialog), findsNothing);
      expect((await products(tester)).length, 2);
    });
  });

  group('aviso al editar un producto (RF-91)', () {
    Future<void> twoProducts() async {
      await product('p-1', 'Aceite', 2500);
      await product('p-2', 'Aceite Mazola', 2800);
    }

    testWidgets('cambiar solo el precio no avisa', (tester) async {
      await pump(
        tester,
        seed: twoProducts,
        editing: Product(
          id: 'p-1',
          businessId: session.businessId,
          name: 'Aceite',
          price: 2500,
          unit: 'ounce',
          archived: false,
          version: 1,
          createdBy: 'u-1',
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      );

      await fill(tester, price: '27');
      await save(tester);

      expect(find.byType(ConfirmDialog), findsNothing);
      expect((await row(tester, 'p-1')).price, 2700);
    });

    testWidgets('renombrar a un nombre ya usado avisa', (tester) async {
      await pump(
        tester,
        seed: twoProducts,
        editing: Product(
          id: 'p-2',
          businessId: session.businessId,
          name: 'Aceite Mazola',
          price: 2800,
          unit: 'ounce',
          archived: false,
          version: 1,
          createdBy: 'u-1',
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      );

      await fill(tester, name: 'Aceite');
      await save(tester);

      expect(find.byType(ConfirmDialog), findsOne);
      expect((await row(tester, 'p-2')).name, 'Aceite Mazola');
    });

    testWidgets('cambiar la unidad a una ya usada con ese nombre avisa', (
      tester,
    ) async {
      await pump(
        tester,
        seed: () async {
          await product('p-1', 'Aceite', 2500, unit: 'ounce');
          await product('p-2', 'Aceite', 9000, unit: 'liter');
        },
        editing: Product(
          id: 'p-2',
          businessId: session.businessId,
          name: 'Aceite',
          price: 9000,
          unit: 'liter',
          archived: false,
          version: 1,
          createdBy: 'u-1',
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      );

      await fill(tester, unit: SaleUnit.ounce);
      await save(tester);

      expect(find.byType(ConfirmDialog), findsOne);
    });

    testWidgets('cambiar solo las mayúsculas de su propio nombre no avisa', (
      tester,
    ) async {
      await pump(
        tester,
        seed: twoProducts,
        editing: Product(
          id: 'p-1',
          businessId: session.businessId,
          name: 'Aceite',
          price: 2500,
          unit: 'ounce',
          archived: false,
          version: 1,
          createdBy: 'u-1',
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      );

      await fill(tester, name: 'ACEITE');
      await save(tester);

      expect(find.byType(ConfirmDialog), findsNothing);
      expect((await row(tester, 'p-1')).name, 'ACEITE');
    });
  });
}
