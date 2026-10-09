import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/ui/ledger/payment_form_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      await insertFiado(db, 'f-1', session.businessId, 'c-1', total: 10000);
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
          home: const PaymentFormScreen(clientId: 'c-1'),
        ),
      ),
    );
    await settle(tester);
  }

  Rect rect(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(ValueKey(key)));

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  group('barra fija del formulario de abono (T167)', () {
    testWidgets('el botón queda abajo, fuera del scroll', (tester) async {
      await pumpScreen(tester);

      final bar = rect(tester, 'payment-bar');
      expect(bar.bottom, 800);
      expect(rect(tester, 'payment-save').bottom, lessThanOrEqualTo(800));
    });

    testWidgets('con el teclado abierto la barra queda sobre el teclado', (
      tester,
    ) async {
      await pumpScreen(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(rect(tester, 'payment-bar').bottom, lessThanOrEqualTo(500));
      expect(rect(tester, 'payment-save').bottom, lessThanOrEqualTo(500));
    });

    testWidgets('el monto de la barra sigue lo escrito y conserva la vista '
        'previa del saldo', (tester) async {
      await pumpScreen(tester);
      expect(text(tester, 'payment-bar-amount'), 'L 0.00');

      await tester.enterText(find.byKey(const ValueKey('payment-input')), '40');
      await tester.pumpAndSettle();

      expect(text(tester, 'payment-bar-amount'), 'L 40.00');
      expect(text(tester, 'payment-after'), 'Debe L 60.00');
    });

    testWidgets('Registrar abono desde la barra guarda el abono', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.enterText(find.byKey(const ValueKey('payment-input')), '40');
      await tester.tap(find.byKey(const ValueKey('payment-save')));
      await settle(tester);

      final payments = (await tester.runAsync(
        () => db.select(db.payments).get(),
      ))!;
      expect(payments.single.amount, 4000);
    });
  });
}
