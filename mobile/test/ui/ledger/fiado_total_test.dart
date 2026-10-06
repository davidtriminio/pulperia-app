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
import 'package:pulperia_mobile/ui/ledger/fiado_form_screen.dart';

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
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await (db.update(db.businesses)
            ..where((b) => b.id.equals(session.businessId)))
          .write(BusinessesCompanion(amountMode: Value(amountMode)));
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      if (archived) {
        await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
          const ClientsCompanion(archived: Value(true)),
        );
      }
      await insertProductNamed(db, 'p-1', session.businessId, 'Arroz', 2500);
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

  Future<void> openTotalMode(
    WidgetTester tester, {
    String amountMode = 'two_decimals',
    bool archived = false,
  }) async {
    await pumpScreen(
      tester,
      home: const FiadoFormScreen(clientId: 'c-1'),
      amountMode: amountMode,
      archived: archived,
    );
    await tester.tap(find.byKey(const ValueKey('mode-total')));
    await tester.pumpAndSettle();
  }

  Future<void> saveWith(WidgetTester tester, String? amount) async {
    if (amount != null) {
      await tester.enterText(
        find.byKey(const ValueKey('fiado-total-input')),
        amount,
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('fiado-save')));
    await settle(tester);
  }

  Future<List<Fiado>> fiados(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiados).get()))!;

  testWidgets('por defecto se registra con detalle de ítems', (tester) async {
    await pumpScreen(tester, home: const FiadoFormScreen(clientId: 'c-1'));

    expect(find.byKey(const ValueKey('product-search')), findsOne);
    expect(find.byKey(const ValueKey('fiado-total-input')), findsNothing);
  });

  testWidgets('"Solo monto" cambia los ítems por un campo de monto', (
    tester,
  ) async {
    await openTotalMode(tester);

    expect(find.byKey(const ValueKey('fiado-total-input')), findsOne);
    expect(find.byKey(const ValueKey('product-search')), findsNothing);
    expect(find.byKey(const ValueKey('cart-line-1')), findsNothing);
  });

  testWidgets('registra el fiado sin ítems con el monto indicado (RF-29)', (
    tester,
  ) async {
    await openTotalMode(tester);

    await saveWith(tester, '125.50');

    final saved = (await fiados(tester)).single;
    expect(saved.clientId, 'c-1');
    expect(saved.total, 12550);
    expect(saved.createdBy, session.userId);
    expect(
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!,
      isEmpty,
    );
    expect(find.byType(FiadoFormScreen), findsNothing);
  });

  testWidgets('el fiado por monto suma al saldo del cliente', (tester) async {
    await pumpScreen(tester, home: const ClientDetailScreen(clientId: 'c-1'));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balance-label'))).data,
      Strings.balanceSettled,
    );

    await tester.tap(find.byKey(const ValueKey('register-fiado')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-total')));
    await tester.pumpAndSettle();
    await saveWith(tester, '40');
    await tester.tap(find.byKey(const ValueKey('register-fiado')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-total')));
    await tester.pumpAndSettle();
    await saveWith(tester, '10.25');

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balance-label'))).data,
      Strings.balanceDebt,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balance-amount'))).data,
      'L 50.25',
    );
  });

  testWidgets('el total mostrado sigue al monto que se escribe', (
    tester,
  ) async {
    await openTotalMode(tester);

    await tester.enterText(
      find.byKey(const ValueKey('fiado-total-input')),
      '75',
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('fiado-total'))).data,
      'L 75.00',
    );
  });

  testWidgets('sin monto pide indicarlo y no guarda', (tester) async {
    await openTotalMode(tester);

    await saveWith(tester, null);

    expect(find.text(Strings.totalRequired), findsOne);
    expect(await fiados(tester), isEmpty);
  });

  testWidgets('un monto de cero se rechaza (RF-32)', (tester) async {
    await openTotalMode(tester);

    await saveWith(tester, '0');

    expect(find.text(Strings.amountNotPositive), findsOne);
    expect(await fiados(tester), isEmpty);
  });

  testWidgets('un monto que no es número se rechaza', (tester) async {
    await openTotalMode(tester);

    await saveWith(tester, 'mucho');

    expect(find.text(Strings.amountInvalid), findsOne);
  });

  testWidgets('más de 2 decimales se rechaza', (tester) async {
    await openTotalMode(tester);

    await saveWith(tester, '10.123');

    expect(find.text(Strings.amountTooManyDecimals), findsOne);
  });

  testWidgets('con montos enteros no se aceptan centavos (RF-36)', (
    tester,
  ) async {
    await openTotalMode(tester, amountMode: 'integer');

    await saveWith(tester, '10.50');

    expect(find.text(Strings.amountNotWhole), findsOne);
    expect(await fiados(tester), isEmpty);
  });

  testWidgets('con montos enteros acepta un lempira entero', (tester) async {
    await openTotalMode(tester, amountMode: 'integer');

    await saveWith(tester, '30');

    expect((await fiados(tester)).single.total, 3000);
  });

  testWidgets('a un cliente archivado no se le fía (RF-76)', (tester) async {
    await openTotalMode(tester, archived: true);

    await saveWith(tester, '30');

    expect(find.text(Strings.clientArchivedFiado), findsOne);
    expect(await fiados(tester), isEmpty);
  });

  testWidgets('cambiar de modo conserva el carrito', (tester) async {
    await pumpScreen(tester, home: const FiadoFormScreen(clientId: 'c-1'));
    await tester.tap(find.byKey(const ValueKey('product-tile-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-total')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mode-items')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cart-line-1')), findsOne);
  });

  testWidgets('en modo monto solo se guarda el monto, no los ítems', (
    tester,
  ) async {
    await pumpScreen(tester, home: const FiadoFormScreen(clientId: 'c-1'));
    await tester.tap(find.byKey(const ValueKey('product-tile-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-total')));
    await tester.pumpAndSettle();

    await saveWith(tester, '20');

    final saved = (await fiados(tester)).single;
    expect(saved.total, 2000);
    expect(
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!,
      isEmpty,
    );
  });
}
