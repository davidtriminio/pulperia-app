import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/l10n/error_messages.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;

  setUp(() {
    db = openDb();
    api = FakeApi();
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

  Future<void> pumpApp(
    WidgetTester tester, {
    Future<void> Function()? seed,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemorySessionStore(
      StoredSession(
        userId: 'u-1',
        email: 'ana@correo.com',
        tokens: tokensAt(api.now),
        activeBusiness: remoteBusiness('b-1'),
      ),
    );
    await tester.runAsync(() async {
      await insertBusiness(db, 'b-1', name: 'Pulpería Ana');
      await insertClient(db, 'c-1', 'b-1');
      await seed?.call();
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

  testWidgets('sin cambios rechazados la entrada del menú no aparece', (
    tester,
  ) async {
    await pumpApp(tester);

    await tapKey(tester, 'home-menu');

    expect(key('menu-rejected'), findsNothing);
  });

  testWidgets('muestra qué se intentó, por qué falló y permite descartarlo', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: () => insertOutboxOp(
        db,
        'op-1',
        'b-1',
        type: 'fiado.create',
        entityId: 'f-9',
        status: 'rejected',
        errorCode: 'client_not_found',
      ),
    );

    await tapKey(tester, 'home-menu');
    await tapKey(tester, 'menu-rejected');

    expect(key('rejected-screen'), findsOne);
    expect(find.text('Registrar fiado'), findsOne);
    expect(find.text(errorMessageForCode('client_not_found')!), findsOne);

    await tapKey(tester, 'rejected-discard-op-1');

    expect(find.text(Strings.rejectedEmpty), findsOne);
    final left = await tester.runAsync(() => db.select(db.outboxOps).get());
    expect(left, isEmpty);
  });

  testWidgets('un código desconocido usa el mensaje genérico', (tester) async {
    await pumpApp(
      tester,
      seed: () => insertOutboxOp(
        db,
        'op-1',
        'b-1',
        type: 'client.update',
        entityId: 'c-1',
        status: 'rejected',
        errorCode: 'algo_nuevo',
      ),
    );

    await tapKey(tester, 'home-menu');
    await tapKey(tester, 'menu-rejected');

    expect(find.text(Strings.errorUnexpected), findsOne);
  });
}
