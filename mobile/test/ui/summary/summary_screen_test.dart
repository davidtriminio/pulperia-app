import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
import 'package:pulperia_mobile/ui/clients/clients_screen.dart';
import 'package:pulperia_mobile/ui/summary/summary_screen.dart';
import 'package:pulperia_mobile/ui/theme.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late String businessId;

  setUp(() {
    db = openDb();
    businessId = devSessionFor(isRelease: false)!.businessId;
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

  /// Ana debe L 70, Beto (archivado) debe L 20, Carla debe L 120, Dora tiene
  /// L 30 a favor y Eli está al día.
  Future<void> seedClients() async {
    Future<void> client(String id, String name) =>
        insertClient(db, id, businessId, name: name);
    await client('c-ana', 'Ana');
    await client('c-beto', 'Beto');
    await client('c-carla', 'Carla');
    await client('c-dora', 'Dora');
    await client('c-eli', 'Eli');
    await insertFiado(db, 'f-1', businessId, 'c-ana', total: 10000);
    await insertPayment(db, 'p-1', businessId, 'c-ana', amount: 3000);
    await insertFiado(db, 'f-2', businessId, 'c-beto', total: 2000);
    await (db.update(db.clients)..where((c) => c.id.equals('c-beto'))).write(
      const ClientsCompanion(archived: Value(true)),
    );
    await insertFiado(db, 'f-3', businessId, 'c-carla', total: 12000);
    await insertPayment(db, 'p-2', businessId, 'c-dora', amount: 3000);
    await insertFiado(
      db,
      'f-4',
      businessId,
      'c-eli',
      total: 500,
      annulledAt: DateTime.utc(2026, 10, 2),
      annulledBy: 'u-1',
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? seed,
    Widget home = const Scaffold(body: SummaryScreen()),
  }) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, devSessionFor(isRelease: false));
      await (seed ?? seedClients)();
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

  Finder key(String k) => find.byKey(ValueKey(k));
  String text(WidgetTester tester, String k) =>
      tester.widget<Text>(key(k)).data!;

  group('resumen del negocio (RF-63 a RF-66)', () {
    testWidgets('la deuda total suma los saldos positivos (RF-63)', (
      tester,
    ) async {
      await pump(tester);

      // Ana 70 + Carla 120; Beto (archivado) no cuenta.
      expect(text(tester, 'summary-debt-total'), 'L 190.00');
    });

    testWidgets('el saldo a favor total sale aparte (RF-64)', (tester) async {
      await pump(tester);

      expect(text(tester, 'summary-credit-total'), 'L 30.00');
    });

    testWidgets('los mayores deudores van de mayor a menor (RF-65)', (
      tester,
    ) async {
      await pump(tester);

      expect(key('debtor-c-carla'), findsOne);
      expect(key('debtor-c-ana'), findsOne);
      double top(String id) => tester.getTopLeft(key('debtor-$id')).dy;
      expect(top('c-carla'), lessThan(top('c-ana')));
      expect(text(tester, 'debtor-amount-c-carla'), 'L 120.00');
      expect(text(tester, 'debtor-amount-c-ana'), 'L 70.00');
    });

    testWidgets('no aparecen archivados, saldados ni clientes a favor', (
      tester,
    ) async {
      await pump(tester);

      expect(key('debtor-c-beto'), findsNothing);
      expect(key('debtor-c-dora'), findsNothing);
      expect(key('debtor-c-eli'), findsNothing);
    });

    testWidgets('un movimiento anulado no cuenta', (tester) async {
      await pump(tester);

      // Eli tiene un fiado anulado de L 5: su saldo es cero.
      expect(text(tester, 'summary-debt-total'), 'L 190.00');
    });

    testWidgets('muestra solo los 10 mayores deudores', (tester) async {
      await pump(
        tester,
        seed: () async {
          for (var i = 0; i < 12; i++) {
            await insertClient(db, 'c-$i', businessId, name: 'Cliente $i');
            await insertFiado(
              db,
              'f-$i',
              businessId,
              'c-$i',
              total: 1000 + i * 100,
            );
          }
        },
      );

      for (var i = 2; i < 12; i++) {
        expect(key('debtor-c-$i'), findsOne, reason: 'c-$i');
      }
      expect(key('debtor-c-0'), findsNothing);
      expect(key('debtor-c-1'), findsNothing);
    });

    testWidgets('sin deudas muestra ceros y un aviso', (tester) async {
      await pump(tester, seed: () => insertClient(db, 'c-1', businessId));

      expect(text(tester, 'summary-debt-total'), 'L 0.00');
      expect(text(tester, 'summary-credit-total'), 'L 0.00');
      expect(find.text('Nadie debe nada por ahora'), findsOne);
    });

    testWidgets('los montos quedan pegados al borde derecho', (tester) async {
      await pump(tester);
      // Pantalla ancha: el hueco se vería si el monto no estuviera pegado.
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pumpAndSettle();

      // Saldo a favor: margen de la lista (16) más el de la tarjeta (16).
      final credit = tester.getRect(key('summary-credit-total'));
      expect(800 - credit.right, lessThan(36));

      for (final id in ['c-carla', 'c-ana']) {
        final tile = tester.getRect(key('debtor-$id'));
        final amount = tester.getRect(key('debtor-amount-$id'));
        expect(tile.right - amount.right, lessThan(24), reason: id);
      }
    });

    testWidgets('tocar un deudor abre su detalle', (tester) async {
      await pump(tester);

      await tester.tap(key('debtor-c-carla'));
      await settle(tester);

      expect(find.byType(ClientDetailScreen), findsOne);
    });

    testWidgets('se actualiza con los cambios locales aún no sincronizados', (
      tester,
    ) async {
      await pump(tester);
      expect(text(tester, 'summary-debt-total'), 'L 190.00');

      // Carla paga todo: se escribe en la base local y se avisa a la lista.
      await tester.runAsync(
        () => insertPayment(db, 'p-9', businessId, 'c-carla', amount: 12000),
      );
      ProviderScope.containerOf(tester.element(find.byType(SummaryScreen)))
          .invalidate(activeClientsProvider);
      await settle(tester);

      expect(text(tester, 'summary-debt-total'), 'L 70.00');
      expect(key('debtor-c-carla'), findsNothing);
    });
  });

  group('navegación', () {
    testWidgets('hay una sección Resumen en la barra inferior', (tester) async {
      await tester.runAsync(
        () => seedDevSession(db, devSessionFor(isRelease: false)),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeSessionProvider.overrideWithValue(devSessionFor()!),
            sessionStoreProvider.overrideWithValue(devSignedInStore()),
          ],
          child: const PulperiaApp(),
        ),
      );
      await settle(tester);

      await tester.tap(key('nav-summary'));
      await settle(tester);

      expect(key('section-summary'), findsOne);
      expect(key('summary-debt-total'), findsOne);
    });
  });
}
