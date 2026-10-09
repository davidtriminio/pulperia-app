import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/ledger/fiado_form_screen.dart';
import 'package:pulperia_mobile/ui/theme.dart';
import 'package:pulperia_mobile/ui/widgets/quick_amounts.dart';

import '../../support/db_fixtures.dart';

void main() {
  group('QuickAmounts', () {
    Future<List<Money>> pumpAndTap(
      WidgetTester tester,
      AmountMode mode,
      List<String> tapKeys,
    ) async {
      final picked = <Money>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: QuickAmounts(mode: mode, onSelected: picked.add),
          ),
        ),
      );
      for (final key in tapKeys) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump();
      }
      return picked;
    }

    testWidgets('ofrece L 50, 100, 200 y 500', (tester) async {
      await pumpAndTap(tester, AmountMode.twoDecimals, const []);

      for (final value in [50, 100, 200, 500]) {
        expect(find.byKey(ValueKey('quick-$value')), findsOne);
      }
    });

    testWidgets('con 2 decimales los botones dicen L 50.00', (tester) async {
      await pumpAndTap(tester, AmountMode.twoDecimals, const []);

      expect(find.text('L 50.00'), findsOne);
      expect(find.text('L 500.00'), findsOne);
    });

    testWidgets('con montos enteros dicen L 50', (tester) async {
      await pumpAndTap(tester, AmountMode.integer, const []);

      expect(find.text('L 50'), findsOne);
    });

    testWidgets('tocar un botón entrega ese monto en la unidad menor', (
      tester,
    ) async {
      final picked = await pumpAndTap(tester, AmountMode.twoDecimals, [
        'quick-100',
        'quick-50',
      ]);

      expect(picked, [const Money(10000), const Money(5000)]);
    });
  });

  group('en "Solo monto" (RF-29)', () {
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

    Future<void> openTotal(
      WidgetTester tester, {
      String amountMode = 'two_decimals',
    }) async {
      await tester.runAsync(() async {
        await seedDevSession(db, session);
        await (db.update(db.businesses)
              ..where((b) => b.id.equals(session.businessId)))
            .write(BusinessesCompanion(amountMode: Value(amountMode)));
        await insertClient(db, 'c-1', session.businessId, name: 'Ana');
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
      await tester.tap(find.byKey(const ValueKey('mode-total')));
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('fiado-total-input')))
        .controller!
        .text;

    Future<void> tapQuick(WidgetTester tester, int lempiras) async {
      final chip = find.byKey(ValueKey('quick-$lempiras'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('los montos rápidos solo aparecen en este modo', (
      tester,
    ) async {
      await openTotal(tester);
      expect(find.byKey(const ValueKey('quick-100')), findsOne);

      await tester.tap(find.byKey(const ValueKey('mode-items')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quick-100')), findsNothing);
    });

    testWidgets('tocar un monto rellena el campo y el total', (tester) async {
      await openTotal(tester);

      await tapQuick(tester, 100);

      expect(fieldText(tester), '100.00');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('fiado-total'))).data,
        'L 100.00',
      );
    });

    testWidgets('con montos enteros rellena sin centavos', (tester) async {
      await openTotal(tester, amountMode: 'integer');

      await tapQuick(tester, 200);

      expect(fieldText(tester), '200');
    });

    testWidgets('tocar otro monto reemplaza al anterior', (tester) async {
      await openTotal(tester);

      await tapQuick(tester, 100);
      await tapQuick(tester, 50);

      expect(fieldText(tester), '50.00');
    });

    testWidgets('el campo sigue editable a mano después de tocar un monto', (
      tester,
    ) async {
      await openTotal(tester);
      await tapQuick(tester, 100);

      await tester.enterText(
        find.byKey(const ValueKey('fiado-total-input')),
        '125.50',
      );
      await tester.pump();

      expect(fieldText(tester), '125.50');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('fiado-total'))).data,
        'L 125.50',
      );
    });

    testWidgets('se puede escribir sin tocar ningún botón', (tester) async {
      await openTotal(tester);

      await tester.enterText(
        find.byKey(const ValueKey('fiado-total-input')),
        '37',
      );
      await tester.tap(find.byKey(const ValueKey('fiado-save')));
      await settle(tester);

      final saved = (await tester.runAsync(() => db.select(db.fiados).get()))!;
      expect(saved.single.total, 3700);
    });

    testWidgets('registrar con un monto rápido guarda ese total', (
      tester,
    ) async {
      await openTotal(tester);
      await tapQuick(tester, 200);

      await tester.tap(find.byKey(const ValueKey('fiado-save')));
      await settle(tester);

      final saved = (await tester.runAsync(() => db.select(db.fiados).get()))!;
      expect(saved.single.total, 20000);
      expect(
        (await tester.runAsync(() => db.select(db.fiadoItems).get()))!,
        isEmpty,
      );
    });

    testWidgets('un error del campo desaparece al tocar un monto', (
      tester,
    ) async {
      await openTotal(tester);
      await tester.tap(find.byKey(const ValueKey('fiado-save')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.totalRequired), findsOne);

      await tapQuick(tester, 50);

      expect(find.text(Strings.totalRequired), findsNothing);
    });
  });
}
