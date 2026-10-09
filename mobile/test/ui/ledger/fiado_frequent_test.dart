import 'package:drift/drift.dart' show Value;
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

  /// [products] productos `p-00`, `p-01`... del más antiguo al más reciente;
  /// los ids de [fiadoProducts] se han fiado antes.
  Future<void> pumpScreen(
    WidgetTester tester, {
    int products = 12,
    List<String> fiadoProducts = const [],
    List<String> archived = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      for (var i = 0; i < products; i++) {
        final id = 'p-${i.toString().padLeft(2, '0')}';
        await insertProductNamed(db, id, session.businessId, 'Prod $id', 1000);
        await (db.update(db.products)..where((p) => p.id.equals(id))).write(
          ProductsCompanion(
            createdAt: Value(DateTime.utc(2026, 9, 1 + i)),
            archived: Value(archived.contains(id)),
          ),
        );
      }
      var n = 0;
      for (final id in fiadoProducts) {
        n++;
        await insertFiado(db, 'f-$n', session.businessId, 'c-1');
        await insertFiadoItem(
          db,
          'i-$n',
          session.businessId,
          'f-$n',
          productId: id,
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

  final tiles = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('product-tile-'),
  );
  Finder tile(String id) => find.byKey(ValueKey('product-tile-$id'));
  Finder inSheet(Finder f) =>
      find.descendant(of: find.byKey(const ValueKey('all-sheet')), matching: f);

  String total(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('fiado-total'))).data!;

  Future<void> openAll(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('see-all'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('catálogo de entrada limitado (RF-26, RF-30)', () {
    testWidgets('de entrada hay como máximo 8 productos y "Ver todos"', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(tiles, findsNWidgets(8));
      expect(find.byKey(const ValueKey('see-all')), findsOne);
    });

    testWidgets('sin más de 8 productos no hay "Ver todos"', (tester) async {
      await pumpScreen(tester, products: 8);

      expect(tiles, findsNWidgets(8));
      expect(find.byKey(const ValueKey('see-all')), findsNothing);
    });

    testWidgets('los más fiados salen aunque sean antiguos', (tester) async {
      await pumpScreen(tester, fiadoProducts: ['p-00', 'p-00', 'p-01']);

      expect(tile('p-00'), findsOne);
      expect(tile('p-01'), findsOne);
      // Los más recientes completan: p-11 entra y p-02 no.
      expect(tile('p-11'), findsOne);
      expect(tile('p-02'), findsNothing);
    });

    testWidgets('un toque agrega y otro suma 1', (tester) async {
      await pumpScreen(tester);

      await tester.tap(tile('p-11'));
      await tester.pumpAndSettle();
      expect(total(tester), 'L 10.00');
      await tester.tap(tile('p-11'));
      await tester.pumpAndSettle();
      expect(total(tester), 'L 20.00');
    });
  });

  group('"Ver todos"', () {
    testWidgets('abre la lista completa, sin archivados', (tester) async {
      await pumpScreen(tester, archived: ['p-05']);

      await openAll(tester);

      expect(find.byKey(const ValueKey('all-sheet')), findsOne);
      // 11 activos: los 12 menos el archivado.
      expect(inSheet(tiles), findsNWidgets(11));
      expect(inSheet(tile('p-05')), findsNothing);
      expect(inSheet(tile('p-00')), findsOne);
    });

    testWidgets('un toque ahí agrega al carrito', (tester) async {
      await pumpScreen(tester);
      await openAll(tester);

      await tester.tap(inSheet(tile('p-00')));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(tile('p-00')));
      await tester.pumpAndSettle();

      expect(total(tester), 'L 20.00');
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('all-sheet')),
                matching: find.byKey(const ValueKey('product-count-p-00')),
              ),
            )
            .data,
        '2',
      );
    });

    testWidgets('tiene su propia búsqueda', (tester) async {
      await pumpScreen(tester);
      await openAll(tester);

      await tester.enterText(
        find.byKey(const ValueKey('all-search')),
        'prod p-03',
      );
      await tester.pumpAndSettle();

      expect(inSheet(tiles), findsOne);
      expect(inSheet(tile('p-03')), findsOne);
    });

    testWidgets('"Listo" cierra la hoja y el carrito se conserva', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openAll(tester);
      await tester.tap(inSheet(tile('p-00')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('all-done')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('all-sheet')), findsNothing);
      expect(total(tester), 'L 10.00');
    });
  });

  group('búsqueda en la pantalla', () {
    testWidgets('encuentra productos fuera de los frecuentes', (tester) async {
      await pumpScreen(tester);
      expect(tile('p-00'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'p-00',
      );
      await tester.pumpAndSettle();

      expect(tiles, findsOne);
      expect(tile('p-00'), findsOne);
      expect(find.byKey(const ValueKey('see-all')), findsNothing);
    });

    testWidgets('no ofrece archivados', (tester) async {
      await pumpScreen(tester, archived: ['p-00']);

      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'p-00',
      );
      await tester.pumpAndSettle();

      expect(tiles, findsNothing);
    });

    testWidgets('al borrar la búsqueda vuelven los frecuentes', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey('product-search')),
        'p-00',
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('product-search')), '');
      await tester.pumpAndSettle();

      expect(tiles, findsNWidgets(8));
    });
  });
}
