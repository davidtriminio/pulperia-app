import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/l10n/error_messages.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

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

  Future<void> signIn(WidgetTester tester) async {
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
    await tester.enterText(key('auth-email'), 'beto@correo.com');
    await tester.enterText(key('auth-password'), 'contrasena1');
    await tester.pump();
    await tapKey(tester, 'auth-submit');
  }

  const offer = InvitationOffer(
    id: 'inv-1',
    businessId: 'b-9',
    businessName: 'Abarrotes Cata',
    email: 'beto@correo.com',
  );

  group('invitaciones recibidas (RF-67, RF-68)', () {
    testWidgets('al iniciar sesión se muestran, aunque solo tenga un negocio', (
      tester,
    ) async {
      api.businesses = [remoteBusiness('b-1', name: 'Pulpería Beto')];
      api.offers = [offer];

      await signIn(tester);

      expect(key('business-chooser'), findsOne);
      expect(find.text('Abarrotes Cata'), findsOne);
      expect(key('offer-accept-inv-1'), findsOne);
      expect(key('offer-reject-inv-1'), findsOne);
      // No entró solo al negocio que ya tenía.
      expect(key('nav-clients'), findsNothing);
    });

    testWidgets('sin invitaciones y con un solo negocio entra directo', (
      tester,
    ) async {
      api.businesses = [remoteBusiness('b-1', name: 'Pulpería Beto')];

      await signIn(tester);

      expect(key('nav-clients'), findsOne);
    });

    testWidgets('aceptar agrega el negocio a la lista como empleado', (
      tester,
    ) async {
      api.businesses = [remoteBusiness('b-1', name: 'Pulpería Beto')];
      api.offers = [offer];
      await signIn(tester);

      await tapKey(tester, 'offer-accept-inv-1');

      expect(api.count('acceptInvitation'), 1);
      expect(key('business-tile-b-9'), findsOne);
      expect(key('offer-accept-inv-1'), findsNothing);
      expect(find.text(Strings.roleEmployee), findsWidgets);
    });

    testWidgets('rechazar la quita sin agregar nada', (tester) async {
      api.businesses = [remoteBusiness('b-1', name: 'Pulpería Beto')];
      api.offers = [offer];
      await signIn(tester);

      await tapKey(tester, 'offer-reject-inv-1');

      expect(api.count('rejectInvitation'), 1);
      expect(key('offer-accept-inv-1'), findsNothing);
      expect(key('business-tile-b-9'), findsNothing);
    });

    testWidgets('sin conexión para ver invitaciones no estorba', (
      tester,
    ) async {
      api.businesses = [remoteBusiness('b-1', name: 'Pulpería Beto')];
      api.offers = [offer];
      api.failures['listInvitations'] = const NetworkException();

      await signIn(tester);

      // Sin saber de invitaciones, entra directo como siempre.
      expect(key('nav-clients'), findsOne);
    });

    testWidgets('una invitación que ya no sirve muestra su mensaje', (
      tester,
    ) async {
      api.businesses = [remoteBusiness('b-1', name: 'Pulpería Beto')];
      api.offers = [offer];
      await signIn(tester);
      api.failures['acceptInvitation'] = const ApiException(
        409,
        'invitation_not_pending',
        ['invitation_not_pending'],
      );

      await tapKey(tester, 'offer-accept-inv-1');

      expect(
        find.text(errorMessageForCode('invitation_not_pending')!),
        findsOne,
      );
    });
  });
}
