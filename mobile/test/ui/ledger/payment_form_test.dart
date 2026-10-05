import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
import 'package:pulperia_mobile/ui/ledger/payment_form_screen.dart';

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
    String amountMode = 'two_decimals',
    bool archived = false,
    int debt = 10000,
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
      if (archived) {
        await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
          const ClientsCompanion(archived: Value(true)),
        );
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    String amountMode = 'two_decimals',
    bool archived = false,
    int debt = 10000,
  }) =>
      pumpScreen(
        tester,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PaymentFormScreen(clientId: 'c-1'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
        amountMode: amountMode,
        archived: archived,
        debt: debt,
      ).then((_) async {
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
      });

  Future<void> typeAmount(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('payment-input')), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester, [String? amount]) async {
    if (amount != null) {
      await typeAmount(tester, amount);
    }
    await tester.tap(find.byKey(const ValueKey('payment-save')));
    await settle(tester);
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<List<Payment>> payments(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.payments).get()))!;

  group('saldo antes y después del abono (RF-39)', () {
    testWidgets('muestra el saldo actual del cliente', (tester) async {
      await pumpForm(tester);

      expect(
        text(tester, 'payment-current'),
        '${Strings.balanceDebt} L 100.00',
      );
      expect(find.byKey(const ValueKey('payment-after')), findsNothing);
    });

    testWidgets('un abono menor deja una deuda menor', (tester) async {
      await pumpForm(tester);

      await typeAmount(tester, '30');

      expect(text(tester, 'payment-after'), '${Strings.balanceDebt} L 70.00');
    });

    testWidgets('un abono igual a la deuda deja al cliente al día', (
      tester,
    ) async {
      await pumpForm(tester);

      await typeAmount(tester, '100');

      expect(text(tester, 'payment-after'), Strings.balanceSettled);
    });

    testWidgets('un abono mayor muestra la diferencia como saldo a favor', (
      tester,
    ) async {
      await pumpForm(tester);

      await typeAmount(tester, '120.50');

      expect(text(tester, 'payment-after'), '${Strings.balanceCredit} L 20.50');
    });

    testWidgets('un monto inválido no muestra vista previa', (tester) async {
      await pumpForm(tester);

      await typeAmount(tester, 'abc');

      expect(find.byKey(const ValueKey('payment-after')), findsNothing);
    });

    testWidgets('un cliente sin deuda muestra "Al día" como saldo actual', (
      tester,
    ) async {
      await pumpForm(tester, debt: 0);

      expect(text(tester, 'payment-current'), Strings.balanceSettled);
    });
  });

  group('registrar el abono (RF-37)', () {
    testWidgets('guarda el abono y cierra el formulario', (tester) async {
      await pumpForm(tester);

      await save(tester, '40.25');

      final saved = (await payments(tester)).single;
      expect(saved.clientId, 'c-1');
      expect(saved.amount, 4025);
      expect(saved.createdBy, session.userId);
      expect(find.byType(PaymentFormScreen), findsNothing);
    });

    testWidgets('el abono se resta del saldo del detalle', (tester) async {
      await pumpScreen(tester, home: const ClientDetailScreen(clientId: 'c-1'));
      expect(text(tester, 'balance-amount'), 'L 100.00');

      await tester.tap(find.byKey(const ValueKey('register-payment')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentFormScreen), findsOne);
      await save(tester, '30');

      expect(text(tester, 'balance-label'), Strings.balanceDebt);
      expect(text(tester, 'balance-amount'), 'L 70.00');
    });

    testWidgets('un abono mayor que la deuda deja saldo a favor', (
      tester,
    ) async {
      await pumpScreen(tester, home: const ClientDetailScreen(clientId: 'c-1'));

      await tester.tap(find.byKey(const ValueKey('register-payment')));
      await tester.pumpAndSettle();
      await save(tester, '130');

      expect(text(tester, 'balance-label'), Strings.balanceCredit);
      expect(text(tester, 'balance-amount'), 'L 30.00');
    });

    testWidgets('un cliente archivado sí admite abonos (RF-75)', (
      tester,
    ) async {
      await pumpForm(tester, archived: true);

      await save(tester, '25');

      expect((await payments(tester)).single.amount, 2500);
      final client = (await tester.runAsync(() => db.select(db.clients).get()))!
          .single;
      expect(client.archived, isTrue);
    });
  });

  group('validación (RF-38)', () {
    testWidgets('sin monto pide indicarlo', (tester) async {
      await pumpForm(tester);

      await save(tester);

      expect(find.text(Strings.totalRequired), findsOne);
      expect(await payments(tester), isEmpty);
    });

    testWidgets('un abono de cero se rechaza', (tester) async {
      await pumpForm(tester);

      await save(tester, '0');

      expect(find.text(Strings.amountNotPositive), findsOne);
      expect(await payments(tester), isEmpty);
    });

    testWidgets('un abono negativo se rechaza', (tester) async {
      await pumpForm(tester);

      await save(tester, '-5');

      expect(find.text(Strings.amountNotPositive), findsOne);
      expect(await payments(tester), isEmpty);
    });

    testWidgets('un monto que no es número se rechaza', (tester) async {
      await pumpForm(tester);

      await save(tester, '5 lempiras');

      expect(find.text(Strings.amountInvalid), findsOne);
    });

    testWidgets('más de 2 decimales se rechaza', (tester) async {
      await pumpForm(tester);

      await save(tester, '1.999');

      expect(find.text(Strings.amountTooManyDecimals), findsOne);
    });

    testWidgets('con montos enteros no se aceptan centavos (RF-36)', (
      tester,
    ) async {
      await pumpForm(tester, amountMode: 'integer');

      await save(tester, '10.50');

      expect(find.text(Strings.amountNotWhole), findsOne);
      expect(await payments(tester), isEmpty);
    });

    testWidgets('corregir el error permite guardar', (tester) async {
      await pumpForm(tester);
      await save(tester, '0');
      expect(find.text(Strings.amountNotPositive), findsOne);

      await save(tester, '15');

      expect((await payments(tester)).single.amount, 1500);
    });
  });
}
