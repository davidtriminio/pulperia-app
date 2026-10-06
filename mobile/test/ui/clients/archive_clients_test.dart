import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
import 'package:pulperia_mobile/ui/clients/clients_screen.dart';
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

  /// Ana (activa, debe L 70) y Beto (archivado, debe L 20).
  Future<void> pump(
    WidgetTester tester, {
    required Widget home,
    Role role = Role.owner,
    bool withArchived = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      await insertFiado(db, 'f-1', session.businessId, 'c-1', total: 10000);
      await insertPayment(db, 'pay-1', session.businessId, 'c-1', amount: 3000);
      if (withArchived) {
        await insertClient(db, 'c-2', session.businessId, name: 'Beto');
        await insertFiado(db, 'f-2', session.businessId, 'c-2', total: 2000);
        await (db.update(db.clients)..where((c) => c.id.equals('c-2'))).write(
          const ClientsCompanion(archived: Value(true)),
        );
      }
    });
    final asRole = DevSession(
      businessId: session.businessId,
      businessName: session.businessName,
      userId: session.userId,
      role: role,
      amountMode: session.amountMode,
      quantityMode: session.quantityMode,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(asRole),
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

  Future<void> tap(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.tap(key(k));
    await settle(tester);
  }

  Future<Client> clientRow(WidgetTester tester, String id) async =>
      (await tester.runAsync(
        () =>
            (db.select(db.clients)..where((c) => c.id.equals(id))).getSingle(),
      ))!;

  group('archivar desde el detalle (RF-20, RF-21)', () {
    testWidgets('el dueño ve la acción; el empleado no', (tester) async {
      await pump(tester, home: const ClientDetailScreen(clientId: 'c-1'));
      expect(key('archive-client'), findsOne);
      expect(key('restore-client'), findsNothing);
    });

    testWidgets('el empleado no ve archivar ni restaurar (RF-21)', (
      tester,
    ) async {
      await pump(
        tester,
        role: Role.employee,
        home: const ClientDetailScreen(clientId: 'c-1'),
      );
      expect(key('archive-client'), findsNothing);
      expect(key('restore-client'), findsNothing);
    });

    testWidgets('pide confirmación y cancelar no cambia nada', (tester) async {
      await pump(tester, home: const ClientDetailScreen(clientId: 'c-1'));

      await tap(tester, 'archive-client');
      expect(find.text('¿Archivar este cliente?'), findsOne);
      await tap(tester, 'archive-cancel');

      expect((await clientRow(tester, 'c-1')).archived, isFalse);
      expect(find.text('Archivado'), findsNothing);
    });

    testWidgets('archivar con saldo pendiente conserva historial y saldo', (
      tester,
    ) async {
      await pump(tester, home: const ClientDetailScreen(clientId: 'c-1'));

      await tap(tester, 'archive-client');
      await tap(tester, 'archive-confirm');

      expect((await clientRow(tester, 'c-1')).archived, isTrue);
      expect(find.text('Archivado'), findsOne);
      expect(text(tester, 'balance-amount'), 'L 70.00');
      expect(key('entry-f-1'), findsOne);
      expect(key('archive-client'), findsNothing);
      expect(key('restore-client'), findsOne);
      final ops = (await tester.runAsync(() => db.select(db.outboxOps).get()))!;
      expect(ops.map((o) => o.type), contains('client.archive'));
    });
  });

  group('restaurar desde el detalle (RF-23)', () {
    testWidgets('el dueño restaura y el cliente vuelve con su saldo', (
      tester,
    ) async {
      await pump(tester, home: const ClientDetailScreen(clientId: 'c-2'));
      expect(find.text('Archivado'), findsOne);

      await tap(tester, 'restore-client');

      expect((await clientRow(tester, 'c-2')).archived, isFalse);
      expect(find.text('Archivado'), findsNothing);
      expect(text(tester, 'balance-amount'), 'L 20.00');
      expect(key('archive-client'), findsOne);
      final ops = (await tester.runAsync(() => db.select(db.outboxOps).get()))!;
      expect(ops.map((o) => o.type), contains('client.restore'));
    });

    testWidgets('el empleado no puede restaurar (RF-21)', (tester) async {
      await pump(
        tester,
        role: Role.employee,
        home: const ClientDetailScreen(clientId: 'c-2'),
      );

      expect(key('restore-client'), findsNothing);
    });
  });

  group('vista de clientes archivados (RF-22)', () {
    testWidgets('la lista normal no muestra archivados', (tester) async {
      await pump(tester, home: const Scaffold(body: ClientsScreen()));

      expect(find.text('Ana'), findsOne);
      expect(find.text('Beto'), findsNothing);
    });

    testWidgets('la vista de archivados muestra su saldo', (tester) async {
      await pump(tester, home: const Scaffold(body: ClientsScreen()));

      await tap(tester, 'open-archived');

      expect(key('archived-clients-screen'), findsOne);
      expect(find.text('Beto'), findsOne);
      expect(find.text('Ana'), findsNothing);
      expect(text(tester, 'balance-amount-c-2'), 'L 20.00');
    });

    testWidgets('sin archivados muestra un aviso', (tester) async {
      await pump(
        tester,
        home: const Scaffold(body: ClientsScreen()),
        withArchived: false,
      );

      await tap(tester, 'open-archived');

      expect(find.text('No hay clientes archivados'), findsOne);
    });

    testWidgets('el empleado también ve la vista de archivados', (
      tester,
    ) async {
      await pump(
        tester,
        role: Role.employee,
        home: const Scaffold(body: ClientsScreen()),
      );

      await tap(tester, 'open-archived');

      expect(find.text('Beto'), findsOne);
    });

    testWidgets('restaurar desde ahí lo devuelve a la lista normal', (
      tester,
    ) async {
      await pump(tester, home: const Scaffold(body: ClientsScreen()));
      await tap(tester, 'open-archived');
      await tester.tap(find.text('Beto'));
      await settle(tester);

      await tap(tester, 'restore-client');
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      // De vuelta en la vista de archivados, ya vacía.
      expect(find.text('No hay clientes archivados'), findsOne);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text('Beto'), findsOne);
      expect(find.text('Ana'), findsOne);
    });
  });
}
