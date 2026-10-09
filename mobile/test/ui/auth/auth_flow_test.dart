import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
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

  /// Deja que terminen las operaciones reales (base, sesión, "red" falsa) y
  /// que la pantalla se reconstruya.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    // Deja terminar las animaciones de menús, diálogos y rutas.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
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
        ],
        child: const PulperiaApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String field, String text) async {
    await tester.enterText(key(field), text);
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String name) async {
    await tester.ensureVisible(key(name));
    await tester.tap(key(name));
    await settle(tester);
  }

  Future<void> fillLogin(
    WidgetTester tester, {
    String email = 'ana@correo.com',
    String password = 'contrasena1',
  }) async {
    await type(tester, 'auth-email', email);
    await type(tester, 'auth-password', password);
  }

  group('inicio de sesión', () {
    testWidgets(
      'sin sesión se ve el inicio de sesión y no las pantallas de trabajo',
      (tester) async {
        await pumpApp(tester);

        expect(key('login-screen'), findsOne);
        expect(key('auth-email'), findsOne);
        expect(key('auth-password'), findsOne);
        expect(key('auth-submit'), findsOne);
        expect(key('nav-clients'), findsNothing);
      },
    );

    testWidgets('enviar vacío marca cada campo con su mensaje en español', (
      tester,
    ) async {
      await pumpApp(tester);

      await tapKey(tester, 'auth-submit');

      expect(find.text(Strings.emailRequired), findsOne);
      expect(find.text(Strings.passwordRequired), findsOne);
      expect(api.calls, isEmpty);
    });

    testWidgets('un correo mal escrito se avisa sin llamar al servidor', (
      tester,
    ) async {
      await pumpApp(tester);

      await fillLogin(tester, email: 'sin-arroba');
      await tapKey(tester, 'auth-submit');

      expect(find.text(Strings.emailInvalid), findsOne);
      expect(api.calls, isEmpty);
    });

    testWidgets(
      'credenciales malas muestran el error en español y se quedan los datos',
      (tester) async {
        api.passwords = {'ana@correo.com': 'la-buena'};
        await pumpApp(tester);

        await fillLogin(tester, password: 'la-mala-123');
        await tapKey(tester, 'auth-submit');

        expect(find.text(Strings.errorInvalidCredentials), findsOne);
        expect(key('login-screen'), findsOne);
        expect(
          tester.widget<TextField>(key('auth-email')).controller?.text,
          'ana@correo.com',
        );
      },
    );

    testWidgets(
      'sin conexión el primer inicio falla con un mensaje en español',
      (tester) async {
        api.offline = true;
        await pumpApp(tester);

        await fillLogin(tester);
        await tapKey(tester, 'auth-submit');

        expect(find.text(Strings.errorOffline), findsOne);
        expect(store.session, isNull);
      },
    );

    testWidgets(
      'con un solo negocio entra directo a las pantallas de trabajo',
      (tester) async {
        api.businesses = [remoteBusiness('b-1', name: 'Pulpería Ana')];
        await pumpApp(tester);

        await fillLogin(tester);
        await tapKey(tester, 'auth-submit');

        expect(key('nav-clients'), findsOne);
        expect(find.text('Pulpería Ana'), findsWidgets);
        expect(key('login-screen'), findsNothing);
      },
    );

    testWidgets('con varios negocios pide elegir y trabaja con el elegido', (
      tester,
    ) async {
      api.businesses = [
        remoteBusiness('b-1', name: 'Pulpería Ana'),
        remoteBusiness('b-2', name: 'Abarrotes Beto', role: Role.employee),
      ];
      await pumpApp(tester);

      await fillLogin(tester);
      await tapKey(tester, 'auth-submit');

      expect(key('business-chooser'), findsOne);
      expect(key('nav-clients'), findsNothing);
      expect(find.text('Pulpería Ana'), findsOne);
      expect(find.text('Abarrotes Beto'), findsOne);
      expect(find.text(Strings.roleOwner), findsOne);
      expect(find.text(Strings.roleEmployee), findsOne);

      await tapKey(tester, 'business-tile-b-2');

      expect(key('nav-clients'), findsOne);
      expect(find.text('Abarrotes Beto'), findsWidgets);
    });

    testWidgets('un doble toque en Entrar inicia sesión una sola vez', (
      tester,
    ) async {
      api.businesses = [remoteBusiness('b-1')];
      await pumpApp(tester);
      await fillLogin(tester);

      await tester.tap(key('auth-submit'));
      await tester.tap(key('auth-submit'));
      await settle(tester);

      expect(api.count('login'), 1);
    });

    testWidgets('la contraseña se puede mostrar y ocultar', (tester) async {
      await pumpApp(tester);

      expect(
        tester.widget<TextField>(key('auth-password')).obscureText,
        isTrue,
      );
      await tapKey(tester, 'auth-password-toggle');
      expect(
        tester.widget<TextField>(key('auth-password')).obscureText,
        isFalse,
      );
    });

    testWidgets(
      'con la sesión guardada se reanuda sin pedir contraseña ni red',
      (tester) async {
        api.offline = true;
        store.session = StoredSession(
          userId: 'u-1',
          email: 'ana@correo.com',
          tokens: tokensAt(api.now),
          activeBusiness: remoteBusiness('b-1', name: 'Pulpería Ana'),
        );
        await tester.runAsync(
          () => insertBusiness(db, 'b-1', name: 'Pulpería Ana'),
        );
        await pumpApp(tester);

        expect(key('nav-clients'), findsOne);
        expect(key('login-screen'), findsNothing);
      },
    );
  });

  group('registro', () {
    Future<void> openRegister(WidgetTester tester) async {
      await pumpApp(tester);
      await tapKey(tester, 'auth-go-register');
    }

    Future<void> fillRegister(
      WidgetTester tester, {
      String email = 'ana@correo.com',
      String password = 'contrasena1',
      String business = 'Pulpería Ana',
      bool modes = true,
    }) async {
      await type(tester, 'auth-email', email);
      await type(tester, 'auth-password', password);
      await type(tester, 'register-business-name', business);
      if (modes) {
        await tapKey(tester, 'amount-two_decimals');
        await tapKey(tester, 'quantity-fractional');
      }
    }

    testWidgets('se pasa del inicio de sesión al registro y de vuelta', (
      tester,
    ) async {
      await openRegister(tester);

      expect(key('register-screen'), findsOne);
      expect(key('register-business-name'), findsOne);
      expect(key('login-screen'), findsNothing);

      await tapKey(tester, 'auth-go-login');

      expect(key('login-screen'), findsOne);
    });

    testWidgets(
      'enviar vacío marca todos los campos, también los modos (RF-7, RF-78)',
      (tester) async {
        await openRegister(tester);

        await tapKey(tester, 'auth-submit');

        expect(find.text(Strings.emailRequired), findsOne);
        expect(find.text(Strings.passwordRequired), findsOne);
        expect(find.text(Strings.businessNameRequired), findsOne);
        expect(find.text(Strings.amountModeRequired), findsOne);
        expect(find.text(Strings.quantityModeRequired), findsOne);
        expect(api.calls, isEmpty);
      },
    );

    testWidgets('una contraseña corta se avisa', (tester) async {
      await openRegister(tester);

      await fillRegister(tester, password: 'corta');
      await tapKey(tester, 'auth-submit');

      expect(find.text(Strings.passwordTooShort), findsOne);
      expect(api.calls, isEmpty);
    });

    testWidgets('un nombre de negocio en blanco se rechaza (RF-78)', (
      tester,
    ) async {
      await openRegister(tester);

      await fillRegister(tester, business: '   ');
      await tapKey(tester, 'auth-submit');

      expect(find.text(Strings.businessNameRequired), findsOne);
      expect(api.calls, isEmpty);
    });

    testWidgets(
      'con datos válidos crea la cuenta, inicia sesión y entra al negocio nuevo',
      (tester) async {
        await openRegister(tester);

        await fillRegister(tester);
        await tapKey(tester, 'auth-submit');

        expect(api.calls.take(2), ['register', 'login']);
        expect(api.businesses.single.name, 'Pulpería Ana');
        expect(api.businesses.single.amountMode.id, 'two_decimals');
        expect(api.businesses.single.quantityMode.id, 'fractional');
        expect(key('nav-clients'), findsOne);
        expect(find.text('Pulpería Ana'), findsWidgets);
      },
    );

    testWidgets('los modos enteros se envían tal como se eligieron', (
      tester,
    ) async {
      await openRegister(tester);

      await fillRegister(tester, modes: false);
      await tapKey(tester, 'amount-integer');
      await tapKey(tester, 'quantity-integer');
      await tapKey(tester, 'auth-submit');

      expect(api.businesses.single.amountMode.id, 'integer');
      expect(api.businesses.single.quantityMode.id, 'integer');
    });

    testWidgets('un correo repetido muestra el error y conserva lo escrito', (
      tester,
    ) async {
      api.failures['register'] = const ApiException(409, 'email_taken', [
        'email_taken',
      ]);
      await openRegister(tester);

      await fillRegister(tester);
      await tapKey(tester, 'auth-submit');

      expect(find.text(Strings.errorEmailTaken), findsOne);
      expect(key('register-screen'), findsOne);
      expect(
        tester
            .widget<TextField>(key('register-business-name'))
            .controller
            ?.text,
        'Pulpería Ana',
      );
    });

    testWidgets('sin conexión no se puede crear la cuenta y se explica', (
      tester,
    ) async {
      api.offline = true;
      await openRegister(tester);

      await fillRegister(tester);
      await tapKey(tester, 'auth-submit');

      expect(find.text(Strings.errorOffline), findsOne);
      expect(key('nav-clients'), findsNothing);
    });
  });

  group('elegir negocio (RF-5, RF-79)', () {
    Future<void> signInWithoutBusinesses(WidgetTester tester) async {
      await pumpApp(tester);
      await fillLogin(tester);
      await tapKey(tester, 'auth-submit');
    }

    testWidgets('sin negocios se explica y se ofrece crear uno o salir', (
      tester,
    ) async {
      await signInWithoutBusinesses(tester);

      expect(key('business-chooser'), findsOne);
      expect(find.text(Strings.noBusinesses), findsOne);
      expect(key('business-create'), findsOne);
      expect(key('business-logout'), findsOne);
    });

    testWidgets('se crea un negocio adicional y se entra a él', (tester) async {
      await signInWithoutBusinesses(tester);

      await tapKey(tester, 'business-create');
      await type(tester, 'register-business-name', 'Segunda sucursal');
      await tapKey(tester, 'amount-integer');
      await tapKey(tester, 'quantity-integer');
      await tapKey(tester, 'business-create-submit');

      expect(api.count('createBusiness'), 1);
      expect(key('nav-clients'), findsOne);
      expect(find.text('Segunda sucursal'), findsWidgets);
    });

    testWidgets('el nombre vacío de un negocio nuevo se rechaza (RF-78)', (
      tester,
    ) async {
      await signInWithoutBusinesses(tester);

      await tapKey(tester, 'business-create');
      await tapKey(tester, 'business-create-submit');

      expect(find.text(Strings.businessNameRequired), findsOne);
      expect(find.text(Strings.amountModeRequired), findsOne);
      expect(api.count('createBusiness'), 0);
    });

    testWidgets('sin red se muestran los negocios guardados en el teléfono', (
      tester,
    ) async {
      api.businesses = [
        remoteBusiness('b-1', name: 'Pulpería Ana'),
        remoteBusiness('b-2', name: 'Abarrotes Beto'),
      ];
      await pumpApp(tester);
      await fillLogin(tester);
      await tapKey(tester, 'auth-submit');
      expect(key('business-chooser'), findsOne);
      // La app se cierra y se abre sin red: sigue pidiendo elegir.
      api.offline = true;
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester);

      expect(find.text('Pulpería Ana'), findsOne);
      expect(find.text('Abarrotes Beto'), findsOne);
    });

    testWidgets('cerrar sesión desde el selector vuelve al inicio de sesión', (
      tester,
    ) async {
      await signInWithoutBusinesses(tester);

      await tapKey(tester, 'business-logout');
      await tapKey(tester, 'logout-confirm');

      expect(key('login-screen'), findsOne);
      expect(store.session, isNull);
    });
  });

  group('menú del negocio activo', () {
    Future<void> signInWithTwoBusinesses(WidgetTester tester) async {
      api.businesses = [
        remoteBusiness('b-1', name: 'Pulpería Ana'),
        remoteBusiness('b-2', name: 'Abarrotes Beto', role: Role.employee),
      ];
      await pumpApp(tester);
      await fillLogin(tester);
      await tapKey(tester, 'auth-submit');
      await tapKey(tester, 'business-tile-b-1');
    }

    testWidgets(
      'cambiar de negocio abre el selector y el elegido pasa a ser el activo',
      (tester) async {
        // Los clientes ya estaban en el teléfono antes de entrar.
        await tester.runAsync(() async {
          await insertBusiness(db, 'b-1', name: 'Pulpería Ana');
          await insertBusiness(db, 'b-2', name: 'Abarrotes Beto');
          await insertClient(db, 'c-1', 'b-1', name: 'Cliente de Ana');
          await insertClient(db, 'c-2', 'b-2', name: 'Cliente de Beto');
        });
        await signInWithTwoBusinesses(tester);
        expect(find.text('Cliente de Ana'), findsOne);

        await tapKey(tester, 'home-menu');
        await tapKey(tester, 'menu-switch-business');
        expect(key('business-chooser'), findsOne);
        await tapKey(tester, 'business-tile-b-2');

        expect(key('business-chooser'), findsNothing);
        expect(find.text('Cliente de Beto'), findsOne);
        expect(find.text('Cliente de Ana'), findsNothing);
      },
    );

    testWidgets('cerrar sesión pide confirmación', (tester) async {
      await signInWithTwoBusinesses(tester);

      await tapKey(tester, 'home-menu');
      await tapKey(tester, 'menu-logout');
      expect(find.text(Strings.logoutConfirmTitle), findsOne);
      await tapKey(tester, 'logout-cancel');
      expect(key('nav-clients'), findsOne);

      await tapKey(tester, 'home-menu');
      await tapKey(tester, 'menu-logout');
      await tapKey(tester, 'logout-confirm');

      expect(key('login-screen'), findsOne);
      expect(store.session, isNull);
    });
  });
}
