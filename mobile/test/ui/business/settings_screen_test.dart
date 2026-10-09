import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
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

  /// Entra a la app con la sesión guardada, en un negocio con ese rol y modos.
  Future<void> pumpApp(
    WidgetTester tester, {
    Role role = Role.owner,
    AmountMode amount = AmountMode.twoDecimals,
    QuantityMode quantity = QuantityMode.fractional,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final business = remoteBusiness(
      'b-1',
      role: role,
      amountMode: amount,
      quantityMode: quantity,
    );
    store.session = StoredSession(
      userId: 'u-1',
      email: 'ana@correo.com',
      tokens: tokensAt(api.now),
      activeBusiness: business,
    );
    api.settings = BusinessSettings(
      name: business.name,
      amountMode: amount,
      quantityMode: quantity,
    );
    await tester.runAsync(() async {
      await db
          .into(db.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'b-1',
              name: business.name,
              amountMode: amount.id,
              quantityMode: quantity.id,
              createdAt: DateTime.utc(2026, 10, 1),
            ),
          );
    });
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

  Future<void> openSettings(WidgetTester tester) async {
    await tapKey(tester, 'home-menu');
    await tapKey(tester, 'menu-settings');
  }

  group('entrada desde el menú (RF-13)', () {
    testWidgets('el dueño ve Ajustes del negocio', (tester) async {
      await pumpApp(tester);

      await tapKey(tester, 'home-menu');

      expect(key('menu-settings'), findsOne);
    });

    testWidgets('el empleado no la ve', (tester) async {
      await pumpApp(tester, role: Role.employee);

      await tapKey(tester, 'home-menu');

      expect(key('menu-settings'), findsNothing);
    });
  });

  group('ajustes del negocio (RF-7 a RF-9, RF-80)', () {
    testWidgets('muestra el nombre y los modos actuales', (tester) async {
      await pumpApp(tester);

      await openSettings(tester);

      expect(key('settings-screen'), findsOne);
      expect(
        tester.widget<TextField>(key('settings-name')).controller?.text,
        'Pulpería Ana',
      );
    });

    testWidgets('con decimales no se ofrece pasar a enteros (RF-9)', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      final amount = tester.widget<SegmentedButton<AmountMode>>(
        find.byType(SegmentedButton<AmountMode>),
      );
      final quantity = tester.widget<SegmentedButton<QuantityMode>>(
        find.byType(SegmentedButton<QuantityMode>),
      );

      bool enabled<T>(List<ButtonSegment<T>> s, T v) =>
          s.firstWhere((x) => x.value == v).enabled;
      expect(enabled(amount.segments, AmountMode.integer), isFalse);
      expect(enabled(amount.segments, AmountMode.twoDecimals), isTrue);
      expect(enabled(quantity.segments, QuantityMode.integer), isFalse);
      expect(enabled(quantity.segments, QuantityMode.fractional), isTrue);
    });

    testWidgets('con enteros sí se ofrece pasar a decimales (RF-8)', (
      tester,
    ) async {
      await pumpApp(
        tester,
        amount: AmountMode.integer,
        quantity: QuantityMode.integer,
      );
      await openSettings(tester);

      await tapKey(tester, 'amount-two_decimals');
      await tapKey(tester, 'settings-save');

      expect(api.settings.amountMode, AmountMode.twoDecimals);
      expect(api.settings.quantityMode, QuantityMode.integer);
      final row = await tester.runAsync(
        () => (db.select(db.businesses)).getSingle(),
      );
      expect(row!.amountMode, 'two_decimals');
    });

    testWidgets('renombrar se aplica al instante en la app y en la base', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.enterText(key('settings-name'), 'Súper Ana');
      await tester.pump();
      await tapKey(tester, 'settings-save');

      expect(api.settings.name, 'Súper Ana');
      // De vuelta en el inicio, ya con el nombre nuevo.
      expect(key('settings-screen'), findsNothing);
      expect(find.text('Súper Ana'), findsWidgets);
      final row = await tester.runAsync(
        () => (db.select(db.businesses)).getSingle(),
      );
      expect(row!.name, 'Súper Ana');
    });

    testWidgets('guardar está deshabilitado mientras no haya cambios', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(key('settings-save'));
      await settle(tester);

      expect(api.count('updateSettings'), 0);
      expect(key('settings-screen'), findsOne);
    });

    testWidgets('un nombre vacío se marca sin llamar al servidor', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.enterText(key('settings-name'), '   ');
      await tester.pump();
      await tapKey(tester, 'settings-save');

      expect(find.text(Strings.businessNameRequired), findsOne);
      expect(api.count('updateSettings'), 0);
    });

    testWidgets('sin conexión avisa y no cambia nada', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      api.failures['updateSettings'] = const NetworkException();

      await tester.enterText(key('settings-name'), 'Otro nombre');
      await tester.pump();
      await tapKey(tester, 'settings-save');

      expect(find.text(Strings.errorOffline), findsOne);
      expect(key('settings-screen'), findsOne);
      expect(api.settings.name, 'Pulpería Ana');
    });

    testWidgets('un rechazo del servidor se muestra en español', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);
      api.failures['updateSettings'] = const ApiException(403, 'forbidden', [
        'forbidden',
      ]);

      await tester.enterText(key('settings-name'), 'Otro nombre');
      await tester.pump();
      await tapKey(tester, 'settings-save');

      expect(find.text(errorMessageForCode('forbidden')!), findsOne);
    });
  });
}
