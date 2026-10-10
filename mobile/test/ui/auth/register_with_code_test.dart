import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
import 'package:pulperia_mobile/l10n/error_messages.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

/// T204: registrarse con un código de invitación, sin negocio propio (RF-105 a RF-107, D-32).
void main() {
  late AppDatabase db;
  late FakeApi api;
  late MemorySessionStore store;

  const business = RemoteBusiness(
    id: 'b-9',
    name: 'Abarrotes Cata',
    role: Role.employee,
    amountMode: AmountMode.integer,
    quantityMode: QuantityMode.integer,
  );

  setUp(() {
    db = openDb();
    api = FakeApi()..redeemable = {'H4N8TW3R': business};
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

  Future<void> type(WidgetTester tester, String field, String text) async {
    await tester.enterText(key(field), text);
    await tester.pump();
  }

  Future<void> openRegister(WidgetTester tester) async {
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
    await tapKey(tester, 'auth-go-register');
  }

  Future<void> fillWithCode(
    WidgetTester tester, {
    String code = 'H4N8-TW3R',
  }) async {
    await tapKey(tester, 'register-has-code');
    await type(tester, 'auth-email', 'dana@correo.com');
    await type(tester, 'auth-password', 'contrasena1');
    await type(tester, 'register-invitation-code', code);
  }

  testWidgets(
    'la opción «Me invitaron con un código» cambia el negocio y los modos por el código',
    (tester) async {
      await openRegister(tester);
      expect(key('register-business-name'), findsOne);
      expect(key('register-invitation-code'), findsNothing);

      await tapKey(tester, 'register-has-code');

      expect(key('register-business-name'), findsNothing);
      expect(key('amount-two_decimals'), findsNothing);
      expect(key('quantity-fractional'), findsNothing);
      expect(key('register-invitation-code'), findsOne);

      await tapKey(tester, 'register-has-code');

      expect(key('register-business-name'), findsOne);
      expect(key('register-invitation-code'), findsNothing);
    },
  );

  testWidgets(
    'con un código válido crea la cuenta, entra al negocio como empleado y no crea ninguno propio',
    (tester) async {
      await openRegister(tester);

      await fillWithCode(tester);
      await tapKey(tester, 'auth-submit');

      expect(api.calls.take(2), ['registerWithInvitationCode', 'login']);
      expect(api.count('register'), 0);
      expect(key('nav-clients'), findsOne);
      expect(api.businesses.map((b) => (b.id, b.role)), [
        ('b-9', Role.employee),
      ]);
      expect(store.session?.activeBusiness?.id, 'b-9');
    },
  );

  testWidgets('sin escribir el código se avisa sin llamar al servidor', (
    tester,
  ) async {
    await openRegister(tester);

    await fillWithCode(tester, code: '');
    await tapKey(tester, 'auth-submit');

    expect(find.text(Strings.codeRequired), findsOne);
    expect(api.calls, isEmpty);
  });

  testWidgets(
    'un código que no sirve muestra el mensaje y no deja sesión ni cuenta a medias',
    (tester) async {
      await openRegister(tester);

      await fillWithCode(tester, code: 'AAAA-AAAA');
      await tapKey(tester, 'auth-submit');

      expect(
        find.text(errorMessageForCode('invalid_invitation_code')!),
        findsOne,
      );
      expect(key('register-screen'), findsOne);
      expect(api.calls, ['registerWithInvitationCode']);
      expect(store.session, isNull);
    },
  );

  testWidgets('sin conexión se explica y no se crea nada', (tester) async {
    await openRegister(tester);
    api.offline = true;

    await fillWithCode(tester);
    await tapKey(tester, 'auth-submit');

    expect(find.text(Strings.errorOffline), findsOne);
    expect(store.session, isNull);
  });

  testWidgets('un correo ya registrado se avisa y el código se conserva', (
    tester,
  ) async {
    await openRegister(tester);
    api.failures['registerWithInvitationCode'] = const ApiException(
      409,
      'email_taken',
      ['email_taken'],
    );

    await fillWithCode(tester);
    await tapKey(tester, 'auth-submit');

    expect(find.text(Strings.errorEmailTaken), findsOne);
    expect(
      tester
          .widget<TextField>(key('register-invitation-code'))
          .controller!
          .text,
      'H4N8-TW3R',
    );
  });
}
