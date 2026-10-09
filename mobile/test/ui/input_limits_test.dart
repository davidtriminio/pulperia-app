import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../support/dev_session.dart';

import 'package:pulperia_mobile/ui/catalog/product_form_screen.dart';
import 'package:pulperia_mobile/ui/clients/client_form_screen.dart';
import 'package:pulperia_mobile/ui/input_limits.dart';
import 'package:pulperia_mobile/ui/ledger/fiado_form_screen.dart';
import 'package:pulperia_mobile/ui/ledger/payment_form_screen.dart';

import '../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DevSession session;

  setUp(() {
    db = openDb();
    session = devSessionFor(isRelease: false)!;
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(devSessionFor()!),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  Future<String> typeInto(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pump();
    return tester.widget<TextField>(finder).controller!.text;
  }

  group('formulario de cliente', () {
    testWidgets('la nota se corta en 300 caracteres aunque se pegue más', (
      tester,
    ) async {
      await pump(tester, const ClientFormScreen());

      final kept = await typeInto(tester, 'field-note', 'x' * 446);

      expect(kept.length, InputLimits.note);
      expect(InputLimits.note, 300);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('note-counter'))).data,
        '300/300',
      );
    });

    testWidgets('al llegar al límite el contador se resalta', (tester) async {
      await pump(tester, const ClientFormScreen());
      final scheme = Theme.of(tester.element(find.byType(Scaffold)))
          .colorScheme;

      await typeInto(tester, 'field-note', 'x' * 299);
      final before = tester
          .widget<Text>(find.byKey(const ValueKey('note-counter')))
          .style!;
      await typeInto(tester, 'field-note', 'x' * 300);
      final atLimit = tester
          .widget<Text>(find.byKey(const ValueKey('note-counter')))
          .style!;

      expect(before.color, isNot(scheme.error));
      expect(atLimit.color, scheme.error);
      expect(atLimit.fontWeight, FontWeight.w700);
    });

    testWidgets('el nombre se corta en 60 caracteres', (tester) async {
      await pump(tester, const ClientFormScreen());

      final kept = await typeInto(tester, 'field-name', 'N' * 100);

      expect(kept.length, InputLimits.name);
      expect(InputLimits.name, 60);
    });

    testWidgets('la dirección se corta en 150 caracteres', (tester) async {
      await pump(tester, const ClientFormScreen());

      final kept = await typeInto(tester, 'field-address', 'D' * 200);

      expect(kept.length, InputLimits.address);
      expect(InputLimits.address, 150);
    });

    testWidgets('el teléfono solo admite dígitos y 8 como máximo', (
      tester,
    ) async {
      await pump(tester, const ClientFormScreen());

      expect(await typeInto(tester, 'field-phone', '9000-0000'), '90000000');
      expect(await typeInto(tester, 'field-phone', 'abc'), '');
      expect(
        await typeInto(tester, 'field-phone', '9000000012345'),
        '90000000',
      );
      expect(InputLimits.phoneDigits, 8);
    });
  });

  group('formulario de producto', () {
    testWidgets('el nombre se corta en 60 y el precio en 10 caracteres', (
      tester,
    ) async {
      await pump(tester, const ProductFormScreen());

      final name = await typeInto(tester, 'field-product-name', 'P' * 100);
      final price = await typeInto(tester, 'field-product-price', '1' * 30);

      expect(name.length, InputLimits.productName);
      expect(price.length, InputLimits.amount);
      expect(InputLimits.productName, 60);
      expect(InputLimits.amount, 10);
    });
  });

  group('formulario de fiado', () {
    testWidgets('el monto total tiene su límite', (tester) async {
      await pump(tester, const FiadoFormScreen(clientId: 'c-1'));
      await tester.tap(find.byKey(const ValueKey('mode-total')));
      await tester.pumpAndSettle();

      final total = await typeInto(tester, 'fiado-total-input', '9' * 30);

      expect(total.length, InputLimits.amount);
    });
  });

  group('formulario de abono', () {
    testWidgets('el monto tiene su límite', (tester) async {
      await pump(tester, const PaymentFormScreen(clientId: 'c-1'));

      final amount = await typeInto(tester, 'payment-input', '9' * 30);

      expect(amount.length, InputLimits.amount);
    });
  });
}
