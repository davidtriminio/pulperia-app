import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    Widget? home,
    bool withProducts = true,
    bool archivedClient = false,
    String amountMode = 'two_decimals',
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await (db.update(db.businesses)
            ..where((b) => b.id.equals(session.businessId)))
          .write(BusinessesCompanion(amountMode: Value(amountMode)));
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      if (archivedClient) {
        await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
          const ClientsCompanion(archived: Value(true)),
        );
      }
      if (withProducts) {
        await insertProductNamed(db, 'p-1', session.businessId, 'Arroz', 2500);
        await insertProductNamed(db, 'p-2', session.businessId, 'Carne', 9000);
        await insertProductNamed(db, 'p-3', session.businessId, 'Azúcar', 1850);
        await insertProductNamed(db, 'p-4', session.businessId, 'Viejo', 999);
        await (db.update(db.products)..where((p) => p.id.equals('p-2'))).write(
          const ProductsCompanion(unit: Value('pound')),
        );
        await (db.update(db.products)..where((p) => p.id.equals('p-4'))).write(
          const ProductsCompanion(archived: Value(true)),
        );
        await insertBusiness(db, 'b-otro');
        await insertProductNamed(db, 'p-9', 'b-otro', 'Ajeno', 100);
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
          home: home ?? const FiadoFormScreen(clientId: 'c-1'),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapTile(WidgetTester tester, String productId) async {
    final tile = find.byKey(ValueKey('product-tile-$productId'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> save(WidgetTester tester) async {
    await tapKey(tester, 'fiado-save');
    await settle(tester);
  }

  Future<List<Fiado>> fiados(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiados).get()))!;

  Future<List<FiadoItem>> items(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!;

  group('cuadrícula del catálogo (RF-26, RF-30)', () {
    testWidgets('muestra los productos activos del negocio con su precio', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byKey(const ValueKey('product-tile-p-1')), findsOne);
      expect(find.byKey(const ValueKey('product-tile-p-2')), findsOne);
      expect(find.byKey(const ValueKey('product-tile-p-3')), findsOne);
      expect(find.text('Arroz'), findsOne);
      expect(find.text('L 25.00'), findsOne);
      expect(find.text('L 90.00'), findsOne);
    });

    testWidgets('muestra la unidad de cada producto', (tester) async {
      await pumpScreen(tester);

      expect(text(tester, 'product-unit-p-2'), 'por libra');
      expect(text(tester, 'product-unit-p-1'), 'por unidad');
    });

    testWidgets('no muestra archivados ni productos de otro negocio', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byKey(const ValueKey('product-tile-p-4')), findsNothing);
      expect(find.byKey(const ValueKey('product-tile-p-9')), findsNothing);
      expect(find.text('Viejo'), findsNothing);
      expect(find.text('Ajeno'), findsNothing);
    });

    testWidgets('con el catálogo vacío lo indica', (tester) async {
      await pumpScreen(tester, withProducts: false);

      expect(find.text(Strings.catalogEmpty), findsOne);
    });
  });

  group('búsqueda', () {
    testWidgets('filtra al escribir, sin distinguir mayúsculas', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'ARR',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('product-tile-p-1')), findsOne);
      expect(find.byKey(const ValueKey('product-tile-p-2')), findsNothing);
      expect(find.byKey(const ValueKey('product-tile-p-3')), findsNothing);
    });

    testWidgets('busca por cualquier parte del nombre', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'car',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('product-tile-p-2')), findsOne);
    });

    testWidgets('sin coincidencias lo dice', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'zzz',
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.noProductsFound), findsOne);
      expect(find.byKey(const ValueKey('product-tile-p-1')), findsNothing);
    });

    testWidgets('al borrar el texto vuelven todos', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'zzz',
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('product-search')), '');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('product-tile-p-3')), findsOne);
    });

    testWidgets('lo agregado al carrito se conserva al filtrar', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapTile(tester, 'p-1');

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'car',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cart-line-1')), findsOne);
    });
  });

  group('un toque agrega, otro suma (RF-30)', () {
    testWidgets('el carrito empieza vacío con una pista', (tester) async {
      await pumpScreen(tester);

      expect(find.text(Strings.cartEmptyHint), findsOne);
      expect(text(tester, 'fiado-total'), 'L 0.00');
    });

    testWidgets('tocar un producto lo agrega con cantidad 1', (tester) async {
      await pumpScreen(tester);

      await tapTile(tester, 'p-1');

      expect(find.byKey(const ValueKey('cart-line-1')), findsOne);
      expect(text(tester, 'line-qty-1'), '1');
      expect(text(tester, 'line-subtotal-1'), 'L 25.00');
      expect(text(tester, 'fiado-total'), 'L 25.00');
      expect(find.text(Strings.cartEmptyHint), findsNothing);
    });

    testWidgets('tocarlo otra vez suma 1 y actualiza la marca del producto', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tapTile(tester, 'p-1');
      await tapTile(tester, 'p-1');
      await tapTile(tester, 'p-1');

      expect(find.byKey(const ValueKey('cart-line-2')), findsNothing);
      expect(text(tester, 'line-qty-1'), '3');
      expect(text(tester, 'product-count-p-1'), '3');
      expect(text(tester, 'fiado-total'), 'L 75.00');
    });

    testWidgets('productos distintos van en líneas distintas', (tester) async {
      await pumpScreen(tester);

      await tapTile(tester, 'p-1');
      await tapTile(tester, 'p-2');

      expect(find.byKey(const ValueKey('cart-line-1')), findsOne);
      expect(find.byKey(const ValueKey('cart-line-2')), findsOne);
      expect(text(tester, 'fiado-total'), 'L 115.00');
    });

    testWidgets('los productos fuera del carrito no llevan marca', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapTile(tester, 'p-1');

      expect(find.byKey(const ValueKey('product-count-p-3')), findsNothing);
    });

    testWidgets('el botón + suma 1 y el − resta 1', (tester) async {
      await pumpScreen(tester);
      await tapTile(tester, 'p-1');

      await tapKey(tester, 'line-plus-1');
      expect(text(tester, 'line-qty-1'), '2');
      await tapKey(tester, 'line-minus-1');
      expect(text(tester, 'line-qty-1'), '1');
    });

    testWidgets('restar de 1 quita la línea', (tester) async {
      await pumpScreen(tester);
      await tapTile(tester, 'p-1');

      await tapKey(tester, 'line-minus-1');

      expect(find.byKey(const ValueKey('cart-line-1')), findsNothing);
      expect(find.text(Strings.cartEmptyHint), findsOne);
      expect(text(tester, 'fiado-total'), 'L 0.00');
    });

    testWidgets('con montos enteros el total va sin centavos', (tester) async {
      await pumpScreen(tester, amountMode: 'integer');

      await tapTile(tester, 'p-1');
      await tapTile(tester, 'p-1');

      expect(text(tester, 'fiado-total'), 'L 50');
    });
  });

  group('registrar el fiado (RF-28, RF-33)', () {
    testWidgets('guarda cada línea con nombre, precio, unidad y producto', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapTile(tester, 'p-1');
      await tapTile(tester, 'p-1');
      await tapTile(tester, 'p-2');

      await save(tester);

      final saved = (await fiados(tester)).single;
      expect(saved.clientId, 'c-1');
      expect(saved.total, 14000);
      expect(saved.createdBy, session.userId);
      final saved2 = {for (final i in await items(tester)) i.productId: i};
      expect(saved2['p-1']!.description, 'Arroz');
      expect(saved2['p-1']!.quantity, 2000);
      expect(saved2['p-1']!.unitPrice, 2500);
      expect(saved2['p-1']!.unit, 'unit');
      expect(saved2['p-2']!.description, 'Carne');
      expect(saved2['p-2']!.unit, 'pound');
      expect(find.byType(FiadoFormScreen), findsNothing);
    });

    testWidgets('con el carrito vacío no guarda y lo dice (RF-33)', (
      tester,
    ) async {
      await pumpScreen(tester);

      await save(tester);

      expect(find.text(Strings.fiadoEmpty), findsOne);
      expect(await fiados(tester), isEmpty);
      expect(find.byType(FiadoFormScreen), findsOne);
    });

    testWidgets('a un cliente archivado no se le fía (RF-76)', (tester) async {
      await pumpScreen(tester, archivedClient: true);
      await tapTile(tester, 'p-1');

      await save(tester);

      expect(find.text(Strings.clientArchivedFiado), findsOne);
      expect(await fiados(tester), isEmpty);
    });

    testWidgets('cambiar a "Solo monto" y volver conserva el carrito', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapTile(tester, 'p-1');

      await tapKey(tester, 'mode-total');
      expect(find.byKey(const ValueKey('product-tile-p-1')), findsNothing);
      await tapKey(tester, 'mode-items');

      expect(find.byKey(const ValueKey('cart-line-1')), findsOne);
      expect(text(tester, 'fiado-total'), 'L 25.00');
    });
  });

  group('desde el detalle del cliente', () {
    testWidgets('"Fiar" abre la pantalla y el saldo se actualiza al guardar', (
      tester,
    ) async {
      await pumpScreen(tester, home: const ClientDetailScreen(clientId: 'c-1'));
      expect(text(tester, 'balance-label'), Strings.balanceSettled);

      await tapKey(tester, 'register-fiado');
      expect(find.byType(FiadoFormScreen), findsOne);
      await tapTile(tester, 'p-3');
      await tapTile(tester, 'p-3');
      await save(tester);

      expect(text(tester, 'balance-label'), Strings.balanceDebt);
      expect(text(tester, 'balance-amount'), 'L 37.00');
    });
  });
}
