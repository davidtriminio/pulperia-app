import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/avatar/avatar_view.dart';
import 'package:pulperia_mobile/ui/clients/client_form_screen.dart';
import 'package:pulperia_mobile/ui/clients/clients_screen.dart';

import '../../support/db_fixtures.dart';

void main() {
  group('crear desde la lista', _fabTests);
  late AppDatabase db;
  late String businessId;

  setUp(() {
    db = openDb();
    businessId = devSessionFor(isRelease: false)!.businessId;
  });
  tearDown(() => db.close());

  Future<void> pumpList(
    WidgetTester tester, {
    Future<void> Function()? seed,
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, devSessionFor(isRelease: false));
      await seed?.call();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: ClientsScreen())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }

  testWidgets('sin clientes muestra el mensaje de lista vacía', (tester) async {
    await pumpList(tester);

    expect(find.text(Strings.clientsEmpty), findsOne);
  });

  testWidgets('lista los clientes con avatar, en orden alfabético', (
    tester,
  ) async {
    await pumpList(
      tester,
      seed: () async {
        await insertClient(db, 'c-2', businessId, name: 'beto');
        await insertClient(db, 'c-1', businessId, name: 'Ana');
      },
    );

    expect(find.byType(AvatarView), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Ana')).dy,
      lessThan(tester.getTopLeft(find.text('beto')).dy),
    );
    expect(find.text(Strings.clientsEmpty), findsNothing);
  });

  testWidgets('los clientes archivados no aparecen', (tester) async {
    await pumpList(
      tester,
      seed: () async {
        await insertClient(db, 'c-1', businessId, name: 'Ana');
        await insertClient(db, 'c-2', businessId, name: 'Carla');
        await (db.update(db.clients)..where((c) => c.id.equals('c-2'))).write(
          const ClientsCompanion(archived: Value(true)),
        );
      },
    );

    expect(find.text('Ana'), findsOne);
    expect(find.text('Carla'), findsNothing);
  });

  testWidgets('distingue deuda, saldo a favor y saldado', (tester) async {
    await pumpList(
      tester,
      seed: () async {
        await insertClient(db, 'c-1', businessId, name: 'Ana');
        await insertClient(db, 'c-2', businessId, name: 'Beto');
        await insertClient(db, 'c-3', businessId, name: 'Carlos');
        await insertFiado(db, 'f-1', businessId, 'c-1', total: 15050);
        await insertPayment(db, 'p-1', businessId, 'c-2', amount: 3000);
      },
    );

    expect(find.byKey(const ValueKey('balance-label-c-1')), findsOne);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balance-label-c-1'))).data,
      Strings.balanceDebt,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('balance-amount-c-1')))
          .data,
      'L 150.50',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balance-label-c-2'))).data,
      Strings.balanceCredit,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('balance-amount-c-2')))
          .data,
      'L 30.00',
    );
    // Un cliente saldado no muestra monto, solo "Al día".
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balance-label-c-3'))).data,
      Strings.balanceSettled,
    );
    expect(find.byKey(const ValueKey('balance-amount-c-3')), findsNothing);
  });

  testWidgets('la deuda y el saldo a favor tienen colores distintos', (
    tester,
  ) async {
    await pumpList(
      tester,
      seed: () async {
        await insertClient(db, 'c-1', businessId, name: 'Ana');
        await insertClient(db, 'c-2', businessId, name: 'Beto');
        await insertFiado(db, 'f-1', businessId, 'c-1', total: 1000);
        await insertPayment(db, 'p-1', businessId, 'c-2', amount: 1000);
      },
    );

    Color? colorOf(String id) => tester
        .widget<Text>(find.byKey(ValueKey('balance-amount-$id')))
        .style
        ?.color;
    final debt = colorOf('c-1');
    final credit = colorOf('c-2');

    expect(debt, isNotNull);
    expect(credit, isNotNull);
    expect(debt, isNot(credit));
  });

  testWidgets('un abono que supera la deuda se ve como saldo a favor', (
    tester,
  ) async {
    await pumpList(
      tester,
      seed: () async {
        await insertClient(db, 'c-1', businessId, name: 'Ana');
        await insertFiado(db, 'f-1', businessId, 'c-1', total: 1000);
        await insertPayment(db, 'p-1', businessId, 'c-1', amount: 1500);
      },
    );

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balance-label-c-1'))).data,
      Strings.balanceCredit,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('balance-amount-c-1')))
          .data,
      'L 5.00',
    );
  });

  testWidgets('no muestra clientes de otro negocio', (tester) async {
    await pumpList(
      tester,
      seed: () async {
        await insertBusiness(db, 'b-otro');
        await insertClient(db, 'c-1', businessId, name: 'Ana');
        await insertClient(db, 'c-9', 'b-otro', name: 'Ajena');
      },
    );

    expect(find.text('Ana'), findsOne);
    expect(find.text('Ajena'), findsNothing);
  });
}

void _fabTests() {
  late AppDatabase db;
  late String businessId;

  setUp(() {
    db = openDb();
    businessId = devSessionFor(isRelease: false)!.businessId;
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedDevSession(db, devSessionFor(isRelease: false));
      await insertClient(db, 'c-1', businessId, name: 'Ana');
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: ClientsScreen()),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }

  testWidgets('el botón Nuevo cliente abre el formulario', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('new-client')));
    await tester.pumpAndSettle();

    expect(find.byType(ClientFormScreen), findsOne);
  });

  testWidgets('un cliente nuevo aparece en la lista al volver', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('new-client')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-name')), 'Beto');
    await tester.tap(find.byKey(const ValueKey('avatar-field')));
    await tester.pumpAndSettle();
    // Tres pasos: personaje, tono de piel y fondo.
    final steps = [
      ['pick-char-01', 'avatar-next'],
      ['pick-skin-1', 'avatar-next'],
      ['pick-bg-01', 'avatar-continue'],
    ];
    for (final step in steps) {
      for (final key in step) {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }
    }
    await tester.tap(find.byKey(const ValueKey('client-save')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beto'), findsOne);
    expect(find.text('Ana'), findsOne);
  });
}
