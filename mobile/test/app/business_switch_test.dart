import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/app/session_state.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/ui/clients/clients_screen.dart';

import '../support/db_fixtures.dart';
import '../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;
  late MemorySessionStore store;

  setUp(() {
    db = openDb();
    api = FakeApi();
    store = MemorySessionStore(
      StoredSession(
        userId: 'u-1',
        email: 'ana@correo.com',
        tokens: tokensAt(api.now),
      ),
    );
  });

  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        pulperiaApiProvider.overrideWithValue(api),
        sessionStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => api.now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('negocios en el controlador de la sesión', () {
    test(
      'elegir un negocio lo deja activo, con su rol, y lo recuerda',
      () async {
        final c = container();
        await c.read(sessionControllerProvider.future);

        await c
            .read(sessionControllerProvider.notifier)
            .chooseBusiness(remoteBusiness('b-2', role: Role.employee));

        final state = c.read(sessionControllerProvider).value! as SignedIn;
        expect(state.active?.id, 'b-2');
        expect(c.read(activeBusinessIdProvider), 'b-2');
        expect(c.read(activeUserProvider).role, Role.employee);
        expect(store.session?.activeBusiness?.id, 'b-2');
      },
    );

    test('cambiar de negocio cambia el negocio activo y su rol', () async {
      final c = container();
      await c.read(sessionControllerProvider.future);
      final controller = c.read(sessionControllerProvider.notifier);

      await controller.chooseBusiness(remoteBusiness('b-1'));
      expect(c.read(activeUserProvider).role, Role.owner);
      await controller.chooseBusiness(
        remoteBusiness('b-2', role: Role.employee),
      );

      expect(c.read(activeBusinessIdProvider), 'b-2');
      expect(c.read(activeUserProvider).role, Role.employee);
    });

    test('cargar los negocios usa el servidor cuando hay red', () async {
      api.businesses = [remoteBusiness('b-1'), remoteBusiness('b-2')];
      final c = container();
      await c.read(sessionControllerProvider.future);

      final list = await c
          .read(sessionControllerProvider.notifier)
          .loadBusinesses();

      expect(list.map((b) => b.id), ['b-1', 'b-2']);
    });

    test(
      'sin red cargar los negocios usa los guardados en el teléfono',
      () async {
        api.businesses = [remoteBusiness('b-1'), remoteBusiness('b-2')];
        final c = container();
        await c.read(sessionControllerProvider.future);
        final controller = c.read(sessionControllerProvider.notifier);
        await controller.loadBusinesses();
        api.offline = true;

        final list = await controller.loadBusinesses();

        expect(list.map((b) => b.id), ['b-1', 'b-2']);
      },
    );

    test(
      'al cargar, el negocio activo toma los datos nuevos del servidor',
      () async {
        final c = container();
        await c.read(sessionControllerProvider.future);
        final controller = c.read(sessionControllerProvider.notifier);
        await controller.chooseBusiness(remoteBusiness('b-1'));
        api.businesses = [
          remoteBusiness('b-1', name: 'Nombre nuevo', role: Role.employee),
        ];

        await controller.loadBusinesses();

        final active = c.read(activeSessionProvider);
        expect(
          (active.businessName, active.role),
          ('Nombre nuevo', Role.employee),
        );
      },
    );

    test(
      'si el servidor ya no lista el negocio activo, se quita como activo',
      () async {
        final c = container();
        await c.read(sessionControllerProvider.future);
        final controller = c.read(sessionControllerProvider.notifier);
        await controller.chooseBusiness(remoteBusiness('b-1'));
        api.businesses = [remoteBusiness('b-2')];

        await controller.loadBusinesses();

        final state = c.read(sessionControllerProvider).value! as SignedIn;
        expect(state.active, isNull);
        expect(store.session?.activeBusiness, isNull);
      },
    );

    test('al iniciar sesión con un solo negocio se elige solo', () async {
      store.session = null;
      api.businesses = [remoteBusiness('b-1')];
      final c = container();
      await c.read(sessionControllerProvider.future);

      await c
          .read(sessionControllerProvider.notifier)
          .login('ana@correo.com', 'contrasena1');

      expect(c.read(activeBusinessIdProvider), 'b-1');
    });

    test(
      'con varios negocios no elige ninguno: lo decide el usuario',
      () async {
        store.session = null;
        api.businesses = [remoteBusiness('b-1'), remoteBusiness('b-2')];
        final c = container();
        await c.read(sessionControllerProvider.future);

        await c
            .read(sessionControllerProvider.notifier)
            .login('ana@correo.com', 'contrasena1');

        final state = c.read(sessionControllerProvider).value! as SignedIn;
        expect(state.active, isNull);
      },
    );

    test('registrarse deja elegido el negocio recién creado', () async {
      store.session = null;
      final c = container();
      await c.read(sessionControllerProvider.future);

      await c
          .read(sessionControllerProvider.notifier)
          .register(
            email: 'ana@correo.com',
            password: 'contrasena1',
            businessName: 'Pulpería Ana',
            amountMode: remoteBusiness('x').amountMode,
            quantityMode: remoteBusiness('x').quantityMode,
          );

      expect(c.read(activeSessionProvider).businessName, 'Pulpería Ana');
      expect(c.read(activeUserProvider).role, Role.owner);
    });

    test('crear un negocio adicional lo deja elegido', () async {
      final c = container();
      await c.read(sessionControllerProvider.future);

      await c
          .read(sessionControllerProvider.notifier)
          .createBusiness(
            name: 'Segunda sucursal',
            amountMode: remoteBusiness('x').amountMode,
            quantityMode: remoteBusiness('x').quantityMode,
          );

      expect(c.read(activeSessionProvider).businessName, 'Segunda sucursal');
    });

    test('cerrar sesión olvida el negocio activo', () async {
      final c = container();
      await c.read(sessionControllerProvider.future);
      final controller = c.read(sessionControllerProvider.notifier);
      await controller.chooseBusiness(remoteBusiness('b-1'));

      await controller.logout();

      expect(c.read(sessionControllerProvider).value, isA<SignedOut>());
      expect(store.session, isNull);
    });
  });

  testWidgets('los datos mostrados son siempre los del negocio activo', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await insertBusiness(db, 'b-1', name: 'Pulpería Ana');
      await insertBusiness(db, 'b-2', name: 'Abarrotes Beto');
      await insertClient(db, 'c-1', 'b-1', name: 'Cliente de Ana');
      await insertClient(db, 'c-2', 'b-2', name: 'Cliente de Beto');
    });
    final c = container();
    await tester.runAsync(() => c.read(sessionControllerProvider.future));
    final controller = c.read(sessionControllerProvider.notifier);
    await tester.runAsync(
      () => controller.chooseBusiness(
        remoteBusiness('b-1', name: 'Pulpería Ana'),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: ClientsScreen()),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();
      }
    }

    await settle();
    expect(find.text('Cliente de Ana'), findsOneWidget);
    expect(find.text('Cliente de Beto'), findsNothing);

    await tester.runAsync(
      () => controller.chooseBusiness(
        remoteBusiness('b-2', name: 'Abarrotes Beto'),
      ),
    );
    await settle();

    expect(find.text('Cliente de Beto'), findsOneWidget);
    expect(find.text('Cliente de Ana'), findsNothing);
  });
}
