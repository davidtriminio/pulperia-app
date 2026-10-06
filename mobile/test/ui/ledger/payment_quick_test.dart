import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
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

  Future<void> openPayment(
    WidgetTester tester, {
    int debt = 10000,
    int paid = 0,
    String amountMode = 'two_decimals',
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await (db.update(db.businesses)
            ..where((b) => b.id.equals(session.businessId)))
          .write(BusinessesCompanion(amountMode: Value(amountMode)));
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      if (debt > 0) {
        await insertFiado(db, 'f-1', session.businessId, 'c-1', total: debt);
      }
      if (paid > 0) {
        await insertPayment(db, 'p-1', session.businessId, 'c-1', amount: paid);
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
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

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('payment-input')))
      .controller!
      .text;

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  group('montos rápidos (RF-37)', () {
    testWidgets('ofrece los montos rápidos', (tester) async {
      await openPayment(tester);

      for (final value in [50, 100, 200, 500]) {
        expect(find.byKey(ValueKey('quick-$value')), findsOne);
      }
    });

    testWidgets('tocar uno rellena el campo y muestra cómo quedaría el saldo', (
      tester,
    ) async {
      await openPayment(tester);

      await tapKey(tester, 'quick-50');

      expect(fieldText(tester), '50.00');
      expect(text(tester, 'payment-after'), '${Strings.balanceDebt} L 50.00');
    });

    testWidgets('con montos enteros rellena sin centavos', (tester) async {
      await openPayment(tester, amountMode: 'integer');

      await tapKey(tester, 'quick-100');

      expect(fieldText(tester), '100');
    });

    testWidgets('el campo sigue editable a mano', (tester) async {
      await openPayment(tester);
      await tapKey(tester, 'quick-50');

      await tester.enterText(
        find.byKey(const ValueKey('payment-input')),
        '37.25',
      );
      await tester.pump();

      expect(fieldText(tester), '37.25');
      expect(text(tester, 'payment-after'), '${Strings.balanceDebt} L 62.75');
    });

    testWidgets('un monto mayor que la deuda deja saldo a favor (RF-39)', (
      tester,
    ) async {
      await openPayment(tester);

      await tapKey(tester, 'quick-200');

      expect(
        text(tester, 'payment-after'),
        '${Strings.balanceCredit} L 100.00',
      );
    });

    testWidgets('tocar un monto limpia el error anterior', (tester) async {
      await openPayment(tester);
      await tapKey(tester, 'payment-save');
      expect(find.text(Strings.totalRequired), findsOne);

      await tapKey(tester, 'quick-100');

      expect(find.text(Strings.totalRequired), findsNothing);
    });
  });

  group('"Saldo completo" (RF-37, RF-39)', () {
    testWidgets('con deuda ofrece pagarla toda', (tester) async {
      await openPayment(tester);

      expect(find.byKey(const ValueKey('pay-full')), findsOne);
    });

    testWidgets('rellena justo lo que debe el cliente', (tester) async {
      await openPayment(tester, debt: 15050);

      await tapKey(tester, 'pay-full');

      expect(fieldText(tester), '150.50');
      expect(text(tester, 'payment-after'), Strings.balanceSettled);
    });

    testWidgets('con montos enteros rellena sin centavos', (tester) async {
      await openPayment(tester, debt: 15000, amountMode: 'integer');

      await tapKey(tester, 'pay-full');

      expect(fieldText(tester), '150');
    });

    testWidgets('tiene en cuenta los abonos anteriores', (tester) async {
      await openPayment(tester, debt: 10000, paid: 2500);

      await tapKey(tester, 'pay-full');

      expect(fieldText(tester), '75.00');
    });

    testWidgets('reemplaza lo escrito antes', (tester) async {
      await openPayment(tester);
      await tester.enterText(find.byKey(const ValueKey('payment-input')), '12');
      await tester.pump();

      await tapKey(tester, 'pay-full');

      expect(fieldText(tester), '100.00');
    });

    testWidgets('no aparece si el cliente no debe nada', (tester) async {
      await openPayment(tester, debt: 0);

      expect(find.byKey(const ValueKey('pay-full')), findsNothing);
    });

    testWidgets('no aparece si el cliente ya tiene saldo a favor', (
      tester,
    ) async {
      await openPayment(tester, debt: 5000, paid: 8000);

      expect(find.byKey(const ValueKey('pay-full')), findsNothing);
    });

    testWidgets('registrarlo deja al cliente al día', (tester) async {
      await openPayment(tester, debt: 15050);

      await tapKey(tester, 'pay-full');
      await tapKey(tester, 'payment-save');
      await settle(tester);

      final payments = (await tester.runAsync(
        () => db.select(db.payments).get(),
      ))!;
      expect(payments.single.amount, 15050);
      expect(find.byType(PaymentFormScreen), findsNothing);
    });
  });
}
