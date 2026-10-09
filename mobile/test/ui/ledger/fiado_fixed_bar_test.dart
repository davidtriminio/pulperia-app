import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

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
    required Widget home,
    int products = 0,
    int fiados = 0,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
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
      for (var i = 0; i < fiados; i++) {
        await insertFiado(db, 'f-$i', session.businessId, 'c-1', total: 500);
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
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  Rect rect(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(ValueKey(key)));

  group('barra fija del formulario de fiado (T166)', () {
    testWidgets('el total y Registrar siguen a la vista con muchas líneas', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        home: const FiadoFormScreen(clientId: 'c-1'),
        products: 6,
      );
      for (var i = 0; i < 6; i++) {
        final tile = find.byKey(ValueKey('product-tile-p-$i'));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }

      // Se desplaza hasta el final y hasta el principio: la barra no se mueve.
      final bar = rect(tester, 'fiado-bar');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(rect(tester, 'fiado-bar'), bar);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(rect(tester, 'fiado-bar'), bar);

      expect(bar.bottom, lessThanOrEqualTo(800));
      expect(rect(tester, 'fiado-save').bottom, lessThanOrEqualTo(800));
      expect(rect(tester, 'fiado-total').bottom, lessThanOrEqualTo(800));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('fiado-total'))).data,
        'L 60.00',
      );
    });

    testWidgets('con el teclado abierto la barra queda sobre el teclado', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        home: const FiadoFormScreen(clientId: 'c-1'),
        products: 2,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(rect(tester, 'fiado-bar').bottom, lessThanOrEqualTo(500));
      expect(rect(tester, 'fiado-save').bottom, lessThanOrEqualTo(500));
    });

    testWidgets('el error del formulario sale sobre la barra', (tester) async {
      await pumpScreen(tester, home: const FiadoFormScreen(clientId: 'c-1'));

      await tester.tap(find.byKey(const ValueKey('fiado-save')));
      await tester.pumpAndSettle();

      final error = rect(tester, 'fiado-form-error');
      expect(error.bottom, lessThanOrEqualTo(rect(tester, 'fiado-save').top));
      expect(error.top, greaterThanOrEqualTo(rect(tester, 'fiado-bar').top));
    });

    testWidgets('el total de la barra se actualiza en solo monto', (
      tester,
    ) async {
      await pumpScreen(tester, home: const FiadoFormScreen(clientId: 'c-1'));

      await tester.tap(find.byKey(const ValueKey('mode-total')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('fiado-total-input')),
        '75',
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('fiado-total'))).data,
        'L 75.00',
      );
      expect(
        rect(tester, 'fiado-total').top,
        greaterThan(rect(tester, 'fiado-bar').top - 1),
      );
    });
  });

  group('detalle del cliente: Fiar y Abonar fijos', () {
    testWidgets('siguen visibles con un historial largo', (tester) async {
      await pumpScreen(
        tester,
        home: const ClientDetailScreen(clientId: 'c-1'),
        fiados: 15,
      );

      final fiar = rect(tester, 'register-fiado');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(rect(tester, 'register-fiado'), fiar);
      expect(fiar.bottom, lessThanOrEqualTo(800));
      expect(rect(tester, 'register-payment').bottom, lessThanOrEqualTo(800));
    });
  });
}
