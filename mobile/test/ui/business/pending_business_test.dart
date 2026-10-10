import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/business/business_status.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

/// T199 y T194: aviso de negocio pendiente de activación o suspendido, sin ofrecer registrar
/// datos y sin perder lo que el teléfono ya tiene (RF-98, RF-102, D-29, D-30).
void main() {
  late AppDatabase db;
  late FakeApi api;
  late MemorySessionStore store;

  setUp(() {
    db = openDb();
    api = FakeApi();
    store = MemorySessionStore();
  });

  tearDown(() => db.close());

  Finder key(String name) => find.byKey(ValueKey(name));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapKey(WidgetTester tester, String name) async {
    await tester.ensureVisible(key(name));
    await tester.tap(key(name));
    await settle(tester);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pulperiaApiProvider.overrideWithValue(api),
          sessionStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => api.now),
          syncWaitProvider.overrideWithValue((_) async {}),
        ],
        child: const PulperiaApp(),
      ),
    );
    await settle(tester);
  }

  /// La sesión ya iniciada con [status] como estado del negocio activo, y el servidor de acuerdo.
  Future<void> signedInWith(BusinessStatus status, {int queued = 0}) async {
    final business = remoteBusiness('b-1', status: status);
    api.businesses = [business];
    store.session = StoredSession(
      userId: 'u-1',
      email: 'ana@correo.com',
      tokens: tokensAt(api.now),
      activeBusiness: business,
    );
    await insertBusiness(db, 'b-1');
    await db
        .into(db.memberships)
        .insert(
          MembershipsCompanion.insert(
            userId: 'u-1',
            businessId: 'b-1',
            role: 'owner',
          ),
        );
    for (var i = 0; i < queued; i++) {
      await insertOutboxOp(db, 'op-$i', 'b-1', entityId: 'c-$i');
    }
  }

  group('negocio pendiente de activación (T199)', () {
    testWidgets(
      'entra a la pantalla de espera y no a las de trabajo: no ofrece registrar datos',
      (tester) async {
        await tester.runAsync(() => signedInWith(BusinessStatus.pending));

        await pumpApp(tester);

        expect(key('pending-business'), findsOne);
        expect(find.text(Strings.businessPendingTitle), findsOne);
        expect(key('nav-clients'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    testWidgets('dice cuántos cambios guardados esperan para enviarse', (
      tester,
    ) async {
      await tester.runAsync(
        () => signedInWith(BusinessStatus.pending, queued: 3),
      );

      await pumpApp(tester);

      expect(find.text(Strings.pendingChanges(3)), findsWidgets);
      expect(key('pending-business-queue'), findsOne);
    });

    testWidgets(
      'al activarse y comprobar, entra a trabajar sin reinstalar ni volver a iniciar sesión',
      (tester) async {
        await tester.runAsync(() => signedInWith(BusinessStatus.pending));
        await pumpApp(tester);
        expect(key('pending-business'), findsOne);

        // El super administrador lo activó.
        api.businesses = [remoteBusiness('b-1', status: BusinessStatus.active)];
        await tapKey(tester, 'pending-business-check');

        expect(key('pending-business'), findsNothing);
        expect(key('nav-clients'), findsOne);
        expect(store.session?.activeBusiness?.status, BusinessStatus.active);
      },
    );

    testWidgets('si sigue pendiente, lo dice y se queda', (tester) async {
      await tester.runAsync(() => signedInWith(BusinessStatus.pending));
      await pumpApp(tester);

      await tapKey(tester, 'pending-business-check');

      expect(key('pending-business'), findsOne);
      expect(find.text(Strings.businessStillPending), findsOne);
    });

    testWidgets('sin conexión al comprobar lo explica y no pierde nada', (
      tester,
    ) async {
      await tester.runAsync(
        () => signedInWith(BusinessStatus.pending, queued: 1),
      );
      await pumpApp(tester);
      api.offline = true;

      await tapKey(tester, 'pending-business-check');

      expect(key('pending-business'), findsOne);
      expect(find.text(Strings.errorOffline), findsOne);
    });

    testWidgets('puede elegir otro negocio activo si tiene uno', (
      tester,
    ) async {
      await tester.runAsync(() => signedInWith(BusinessStatus.pending));
      api.businesses = [
        remoteBusiness('b-1', status: BusinessStatus.pending),
        remoteBusiness('b-2', name: 'Abarrotes Beto'),
      ];
      await pumpApp(tester);

      await tapKey(tester, 'pending-business-switch');
      await tapKey(tester, 'business-tile-b-2');

      expect(key('pending-business'), findsNothing);
      expect(key('nav-clients'), findsOne);
      expect(store.session?.activeBusiness?.id, 'b-2');
    });

    testWidgets('en la lista de negocios se ve cuál está pendiente', (
      tester,
    ) async {
      await tester.runAsync(() => signedInWith(BusinessStatus.pending));
      api.businesses = [
        remoteBusiness('b-1', status: BusinessStatus.pending),
        remoteBusiness('b-2', name: 'Abarrotes Beto'),
      ];
      await pumpApp(tester);
      await tapKey(tester, 'pending-business-switch');

      expect(key('business-status-b-1'), findsOne);
      expect(find.text(Strings.statusPending), findsOne);
      expect(key('business-status-b-2'), findsNothing);
    });
  });

  group('al sincronizar descubre que el negocio está pendiente (T199)', () {
    testWidgets(
      'pendiente: pasa a la pantalla de espera y la cola se conserva',
      (tester) async {
        await tester.runAsync(
          () => signedInWith(BusinessStatus.active, queued: 2),
        );
        api.failures['push'] = const ApiException(403, 'business_pending', [
          'business_pending',
        ]);

        await pumpApp(tester);

        expect(key('pending-business'), findsOne);
        final queue = await tester.runAsync(
          () => db.select(db.outboxOps).get(),
        );
        expect(queue, hasLength(2));
      },
    );
  });
}
