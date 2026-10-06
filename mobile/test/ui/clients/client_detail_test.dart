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
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
import 'package:pulperia_mobile/ui/clients/client_form_screen.dart';
import 'package:pulperia_mobile/ui/clients/clients_screen.dart';
import 'package:pulperia_mobile/ui/format/date_format.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late String businessId;

  final day1 = DateTime.utc(2026, 10, 1, 14, 0);
  final day2 = DateTime.utc(2026, 10, 2, 15, 30);
  final day3 = DateTime.utc(2026, 10, 3, 9, 15);

  setUp(() {
    db = openDb();
    businessId = devSessionFor(isRelease: false)!.businessId;
  });
  tearDown(() => db.close());

  Future<void> pumpDetail(
    WidgetTester tester, {
    String clientId = 'c-1',
    Future<void> Function()? seed,
    Widget? home,
  }) async {
    // Ventana alta: el historial es una lista perezosa y, con la acción
    // "Anular" del dueño, las tarjetas ocupan más.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, devSessionFor(isRelease: false));
      await insertClient(db, 'c-1', businessId, name: 'Ana López');
      await seed?.call();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home ?? ClientDetailScreen(clientId: clientId),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }

  testWidgets('muestra nombre, avatar y los datos de contacto', (tester) async {
    await pumpDetail(
      tester,
      seed: () =>
          (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
            const ClientsCompanion(
              phone: Value('90000000'),
              address: Value('Frente a la iglesia'),
              note: Value('Paga los viernes'),
            ),
          ),
    );

    expect(find.text('Ana López'), findsWidgets);
    expect(find.byType(AvatarView), findsOne);
    expect(find.text('90000000'), findsOne);
    expect(find.text('Frente a la iglesia'), findsOne);
    expect(find.text('Paga los viernes'), findsOne);
  });

  testWidgets('sin contacto no muestra filas vacías', (tester) async {
    await pumpDetail(tester);

    expect(find.byKey(const ValueKey('contact-phone')), findsNothing);
    expect(find.byKey(const ValueKey('contact-address')), findsNothing);
    expect(find.byKey(const ValueKey('contact-note')), findsNothing);
  });

  testWidgets('sin movimientos: saldo al día y mensaje de historial vacío', (
    tester,
  ) async {
    await pumpDetail(tester);

    expectBalance(tester, Strings.balanceSettled, 'L 0.00');
    expect(find.text(Strings.historyEmpty), findsOne);
  });

  testWidgets('el saldo muestra la deuda', (tester) async {
    await pumpDetail(
      tester,
      seed: () async {
        await insertFiado(
          db,
          'f-1',
          businessId,
          'c-1',
          total: 15050,
          occurredAt: day1,
        );
        await insertPayment(
          db,
          'p-1',
          businessId,
          'c-1',
          amount: 5000,
          occurredAt: day2,
        );
      },
    );

    expectBalance(tester, Strings.balanceDebt, 'L 100.50');
  });

  testWidgets('un abono mayor que la deuda se ve como saldo a favor', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      seed: () async {
        await insertFiado(db, 'f-1', businessId, 'c-1', total: 1000);
        await insertPayment(db, 'p-1', businessId, 'c-1', amount: 1500);
      },
    );

    expectBalance(tester, Strings.balanceCredit, 'L 5.00');
  });

  testWidgets('el historial va del más antiguo al más reciente', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      seed: () async {
        await insertPayment(
          db,
          'p-1',
          businessId,
          'c-1',
          amount: 2000,
          occurredAt: day3,
        );
        await insertFiado(
          db,
          'f-1',
          businessId,
          'c-1',
          total: 5000,
          occurredAt: day1,
        );
        await insertFiado(
          db,
          'f-2',
          businessId,
          'c-1',
          total: 3000,
          occurredAt: day2,
        );
      },
    );

    double top(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('entry-$id'))).dy;
    expect(top('f-1'), lessThan(top('f-2')));
    expect(top('f-2'), lessThan(top('p-1')));
    expect(find.text(formatDateTime(day1)), findsOne);
    expect(find.text('+ L 50.00'), findsOne);
    expect(find.text('− L 20.00'), findsOne);
    expect(find.text(Strings.entryFiado), findsNWidgets(2));
    expect(find.text(Strings.entryPayment), findsOne);
  });

  testWidgets('un fiado con ítems muestra su detalle', (tester) async {
    await pumpDetail(
      tester,
      seed: () async {
        await insertFiado(db, 'f-1', businessId, 'c-1', total: 6250);
        await insertFiadoItem(
          db,
          'i-1',
          businessId,
          'f-1',
          description: 'Arroz',
          quantity: 2500,
          unitPrice: 2500,
          subtotal: 6250,
        );
      },
    );

    expect(find.text('Arroz'), findsOne);
    expect(find.text('2.5 unidades × L 25.00'), findsOne);
    expect(find.text('L 62.50'), findsWidgets);
  });

  testWidgets('los movimientos anulados aparecen con marca visible', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      seed: () async {
        await insertFiado(
          db,
          'f-1',
          businessId,
          'c-1',
          total: 5000,
          annulledAt: day3,
          annulledBy: 'u-1',
        );
        await insertFiado(db, 'f-2', businessId, 'c-1', total: 3000);
        await insertPayment(
          db,
          'p-1',
          businessId,
          'c-1',
          amount: 1000,
          annulledAt: day3,
          annulledBy: 'u-1',
        );
      },
    );

    expect(find.byKey(const ValueKey('annulled-f-1')), findsOne);
    expect(find.byKey(const ValueKey('annulled-p-1')), findsOne);
    expect(find.byKey(const ValueKey('annulled-f-2')), findsNothing);
    expect(find.text(Strings.annulled), findsNWidgets(2));
    // Los anulados no cuentan en el saldo (RF-44): solo queda el fiado de 30.
    expectBalance(tester, Strings.balanceDebt, 'L 30.00');
  });

  testWidgets('un cliente archivado se indica y conserva saldo e historial', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      seed: () async {
        await insertFiado(db, 'f-1', businessId, 'c-1', total: 5000);
        await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
          const ClientsCompanion(archived: Value(true)),
        );
      },
    );

    expect(find.text(Strings.archivedBadge), findsOne);
    expect(find.byKey(const ValueKey('entry-f-1')), findsOne);
    expectBalance(tester, Strings.balanceDebt, 'L 50.00');
  });

  testWidgets(
    'la etiqueta de deuda y la de saldo a favor tienen distinto color',
    (tester) async {
      Color chipColor() =>
          (tester
                      .widget<Container>(
                        find.byKey(const ValueKey('balance-chip')),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;

      await pumpDetail(
        tester,
        seed: () => insertFiado(db, 'f-1', businessId, 'c-1', total: 1000),
      );
      final debt = chipColor();
      await tester.pumpWidget(const SizedBox());
      await db.close();
      db = openDb();
      await pumpDetail(
        tester,
        seed: () => insertPayment(db, 'p-1', businessId, 'c-1', amount: 1000),
      );
      final credit = chipColor();

      expect(debt, isNot(credit));
    },
  );

  testWidgets('un cliente que no existe lo indica', (tester) async {
    await pumpDetail(tester, clientId: 'no-existe');

    expect(find.text(Strings.clientNotFound), findsOne);
  });

  testWidgets('editar abre el formulario y el detalle se actualiza', (
    tester,
  ) async {
    await pumpDetail(tester);

    await tester.tap(find.byKey(const ValueKey('edit-client')));
    await tester.pumpAndSettle();
    expect(find.byType(ClientFormScreen), findsOne);

    await tester.enterText(
      find.byKey(const ValueKey('field-name')),
      'Ana María',
    );
    await tester.tap(find.byKey(const ValueKey('client-save')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClientFormScreen), findsNothing);
    expect(find.text('Ana María'), findsWidgets);
  });

  testWidgets('tocar un cliente de la lista abre su detalle', (tester) async {
    await pumpDetail(tester, home: const Scaffold(body: ClientsScreen()));

    await tester.tap(find.text('Ana López'));
    await tester.pumpAndSettle();

    expect(find.byType(ClientDetailScreen), findsOne);
  });
}

/// El saldo destacado del detalle: etiqueta y monto, cada uno con su clave.
void expectBalance(WidgetTester tester, String label, String amount) {
  expect(
    tester.widget<Text>(find.byKey(const ValueKey('balance-label'))).data,
    label,
  );
  expect(
    tester.widget<Text>(find.byKey(const ValueKey('balance-amount'))).data,
    amount,
  );
}
