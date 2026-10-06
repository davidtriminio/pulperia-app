import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
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

  /// Un cliente con un fiado de L 100 y un abono de L 30 (debe L 70).
  Future<void> pumpDetail(WidgetTester tester, {Role role = Role.owner}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      await insertFiado(
        db,
        'f-1',
        session.businessId,
        'c-1',
        total: 10000,
        occurredAt: DateTime.utc(2026, 10, 1),
      );
      await insertPayment(
        db,
        'pay-1',
        session.businessId,
        'c-1',
        amount: 3000,
        occurredAt: DateTime.utc(2026, 10, 2),
      );
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
          home: const ClientDetailScreen(clientId: 'c-1'),
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
    await tester.pumpAndSettle();
  }

  group('anular desde el historial (RF-43, RF-44, RF-45)', () {
    testWidgets('el dueño ve la acción en fiados y abonos vigentes', (
      tester,
    ) async {
      await pumpDetail(tester);

      expect(key('annul-f-1'), findsOne);
      expect(key('annul-pay-1'), findsOne);
    });

    testWidgets('el empleado no ve la acción (RF-45)', (tester) async {
      await pumpDetail(tester, role: Role.employee);

      expect(key('entry-f-1'), findsOne);
      expect(key('annul-f-1'), findsNothing);
      expect(key('annul-pay-1'), findsNothing);
    });

    testWidgets('pide confirmación y cancelar no cambia nada', (tester) async {
      await pumpDetail(tester);

      await tap(tester, 'annul-pay-1');
      expect(find.text('¿Anular este abono?'), findsOne);
      await tap(tester, 'annul-cancel');

      expect(key('annul-confirm'), findsNothing);
      expect(key('annulled-pay-1'), findsNothing);
      expect(text(tester, 'balance-amount'), 'L 70.00');
      final row = (await tester.runAsync(
        () => db.select(db.payments).getSingle(),
      ))!;
      expect(row.annulledAt, isNull);
    });

    testWidgets('anular un abono lo marca y devuelve la deuda', (tester) async {
      await pumpDetail(tester);

      await tap(tester, 'annul-pay-1');
      await tap(tester, 'annul-confirm');
      await settle(tester);

      expect(key('annulled-pay-1'), findsOne);
      expect(key('annul-pay-1'), findsNothing);
      expect(text(tester, 'balance-amount'), 'L 100.00');
      expect(text(tester, 'balance-label'), 'Debe');
      final row = (await tester.runAsync(
        () => db.select(db.payments).getSingle(),
      ))!;
      expect(row.annulledAt, isNotNull);
      expect(row.annulledBy, session.userId);
    });

    testWidgets('anular un fiado lo marca y deja el abono a favor (RF-47)', (
      tester,
    ) async {
      await pumpDetail(tester);

      await tap(tester, 'annul-f-1');
      expect(find.text('¿Anular este fiado?'), findsOne);
      await tap(tester, 'annul-confirm');
      await settle(tester);

      expect(key('annulled-f-1'), findsOne);
      expect(key('annul-f-1'), findsNothing);
      expect(text(tester, 'balance-amount'), 'L 30.00');
      expect(text(tester, 'balance-label'), 'A favor');
      // El abono sigue vigente y se puede anular.
      expect(key('annul-pay-1'), findsOne);
    });

    testWidgets('la anulación queda en la cola de cambios', (tester) async {
      await pumpDetail(tester);

      await tap(tester, 'annul-f-1');
      await tap(tester, 'annul-confirm');
      await settle(tester);

      final ops = (await tester.runAsync(() => db.select(db.outboxOps).get()))!;
      expect(ops.map((o) => o.type), contains('fiado.annul'));
    });
  });
}
