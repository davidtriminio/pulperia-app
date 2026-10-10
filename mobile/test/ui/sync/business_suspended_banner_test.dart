import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/business/business_status.dart';
import 'package:pulperia_mobile/l10n/error_messages.dart';
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

  group('al sincronizar descubre que el negocio está suspendido (T194)', () {
    testWidgets(
      'suspendido: sigue trabajando con lo que tiene y ve el aviso con la cola intacta',
      (tester) async {
        await tester.runAsync(
          () => signedInWith(BusinessStatus.active, queued: 1),
        );
        api.failures['push'] = const ApiException(403, 'business_suspended', [
          'business_suspended',
        ]);

        await pumpApp(tester);

        expect(key('nav-clients'), findsOne);
        expect(key('business-suspended-banner'), findsOne);
        expect(find.text(Strings.businessSuspended), findsOne);
        final queue = await tester.runAsync(
          () => db.select(db.outboxOps).get(),
        );
        expect(queue, hasLength(1));
      },
    );

    testWidgets('suspendido: al reactivarse el aviso desaparece', (
      tester,
    ) async {
      await tester.runAsync(() => signedInWith(BusinessStatus.suspended));
      await pumpApp(tester);
      expect(key('business-suspended-banner'), findsOne);

      api.businesses = [remoteBusiness('b-1')];
      await tapKey(tester, 'sync-banner-check');

      expect(key('business-suspended-banner'), findsNothing);
    });
  });

  group('mensajes en español (T194)', () {
    test('cada código nuevo tiene su mensaje', () {
      for (final code in [
        'business_pending',
        'business_suspended',
        'account_suspended',
      ]) {
        expect(errorMessageForCode(code), isNotNull, reason: code);
      }
    });

    test('el de cuenta suspendida lo explica', () {
      expect(
        errorMessage(
          const ApiException(403, 'account_suspended', ['account_suspended']),
        ),
        Strings.accountSuspended,
      );
    });
  });
}
