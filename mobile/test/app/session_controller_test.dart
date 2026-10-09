import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/app/session_state.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
import 'package:pulperia_mobile/l10n/error_messages.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

import '../support/db_fixtures.dart';
import '../support/fake_api.dart';

void main() {
  late FakeApi api;
  late MemorySessionStore store;

  setUp(() {
    api = FakeApi();
    store = MemorySessionStore();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        pulperiaApiProvider.overrideWithValue(api),
        sessionStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => api.now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  StoredSession stored({RemoteBusiness? active}) => StoredSession(
    userId: 'u-1',
    email: 'ana@correo.com',
    tokens: tokensAt(api.now),
    activeBusiness: active,
  );

  group('estado de la sesión', () {
    test('sin sesión guardada arranca sin sesión', () async {
      final c = container();

      expect(await c.read(sessionControllerProvider.future), isA<SignedOut>());
    });

    test(
      'con sesión guardada arranca con ella, sin red (reinicio de la app)',
      () async {
        store.session = stored(active: remoteBusiness('b-1'));
        api.offline = true;
        final c = container();

        final state = await c.read(sessionControllerProvider.future);

        expect(state, isA<SignedIn>());
        final signedIn = state as SignedIn;
        expect((signedIn.userId, signedIn.email), ('u-1', 'ana@correo.com'));
        expect(signedIn.active?.id, 'b-1');
        expect(api.calls, isEmpty);
      },
    );

    test('iniciar sesión cambia el estado y guarda la sesión', () async {
      final c = container();
      await c.read(sessionControllerProvider.future);

      await c
          .read(sessionControllerProvider.notifier)
          .login('ana@correo.com', 'contrasena1');

      final state = c.read(sessionControllerProvider).value;
      expect(state, isA<SignedIn>());
      expect((state as SignedIn).active, isNull);
      expect(store.session?.userId, 'u-1');
    });

    test(
      'un inicio de sesión que falla relanza el error y no cambia el estado',
      () async {
        api.offline = true;
        final c = container();
        await c.read(sessionControllerProvider.future);

        await expectLater(
          c
              .read(sessionControllerProvider.notifier)
              .login('ana@correo.com', 'contrasena1'),
          throwsA(isA<NetworkException>()),
        );
        expect(c.read(sessionControllerProvider).value, isA<SignedOut>());
      },
    );

    test('registrarse deja la sesión iniciada', () async {
      final c = container();
      await c.read(sessionControllerProvider.future);

      await c
          .read(sessionControllerProvider.notifier)
          .register(
            email: 'ana@correo.com',
            password: 'contrasena1',
            businessName: 'Pulpería Ana',
            amountMode: AmountMode.twoDecimals,
            quantityMode: QuantityMode.fractional,
          );

      expect(c.read(sessionControllerProvider).value, isA<SignedIn>());
      expect(api.calls, ['register', 'login']);
    });

    test(
      'cerrar sesión vuelve al estado sin sesión y borra lo guardado',
      () async {
        store.session = stored();
        final c = container();
        await c.read(sessionControllerProvider.future);

        await c.read(sessionControllerProvider.notifier).logout();

        expect(c.read(sessionControllerProvider).value, isA<SignedOut>());
        expect(store.session, isNull);
      },
    );
  });

  group('negocio activo', () {
    test('sin negocio elegido no hay sesión de trabajo', () async {
      store.session = stored();
      final c = container();
      await c.read(sessionControllerProvider.future);

      expect(
        () => c.read(activeSessionProvider),
        throwsA(predicate((e) => e.toString().contains('negocio elegido'))),
      );
    });

    test('con negocio elegido da usuario, rol, negocio y modos', () async {
      store.session = stored(
        active: remoteBusiness(
          'b-9',
          name: 'Abarrotes Beto',
          role: Role.employee,
          amountMode: AmountMode.integer,
          quantityMode: QuantityMode.integer,
        ),
      );
      final c = container();
      await c.read(sessionControllerProvider.future);

      final active = c.read(activeSessionProvider);

      expect(active.userId, 'u-1');
      expect(active.businessId, 'b-9');
      expect(active.businessName, 'Abarrotes Beto');
      expect(active.role, Role.employee);
      expect(active.amountMode, AmountMode.integer);
      expect(c.read(activeUserProvider).role, Role.employee);
      expect(c.read(activeBusinessIdProvider), 'b-9');
    });
  });

  group('mensajes de error en español (RNF-5)', () {
    test('sin conexión', () {
      expect(errorMessage(const NetworkException()), Strings.errorOffline);
      expect(Strings.errorOffline, contains('conexión'));
    });

    test('códigos de la API conocidos', () {
      expect(
        errorMessage(const ApiException(401, 'invalid_credentials')),
        Strings.errorInvalidCredentials,
      );
      expect(
        errorMessage(const ApiException(409, 'email_taken')),
        Strings.errorEmailTaken,
      );
    });

    test('un código desconocido da un mensaje genérico, nunca el código', () {
      final message = errorMessage(const ApiException(500, 'algo_nuevo'));

      expect(message, Strings.errorUnexpected);
      expect(message, isNot(contains('algo_nuevo')));
    });

    test('sesión terminada', () {
      expect(
        errorMessage(const SessionExpiredException()),
        Strings.errorSessionExpired,
      );
    });
  });

  group('puerta de acceso', () {
    late AppDatabase db;

    setUp(() => db = openDb());
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            pulperiaApiProvider.overrideWithValue(api),
            sessionStoreProvider.overrideWithValue(store),
          ],
          child: const PulperiaApp(),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    testWidgets('sin sesión no se ven las pantallas de trabajo', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('auth-pending')), findsOne);
      expect(find.byKey(const ValueKey('nav-clients')), findsNothing);
    });

    testWidgets('con sesión pero sin negocio elegido tampoco', (tester) async {
      store.session = stored();
      await pump(tester);

      expect(find.byKey(const ValueKey('auth-pending')), findsOne);
      expect(find.byKey(const ValueKey('nav-clients')), findsNothing);
    });
  });

  test('la sesión simulada de depuración ya no existe en la app', () {
    expect(Directory('lib/dev').existsSync(), isFalse);
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        expect(
          file.readAsStringSync(),
          isNot(contains('DevSession')),
          reason: file.path,
        );
      }
    }
  });
}
