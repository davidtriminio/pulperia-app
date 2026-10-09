import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/app/sync_controller.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/sync/sync_triggers.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;
  late StreamController<bool> online;

  setUp(() async {
    db = openDb();
    api = FakeApi();
    online = StreamController<bool>();
    await insertBusiness(db, 'b-1');
  });

  tearDown(() async {
    await online.close();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpTriggers(WidgetTester tester) async {
    final store = MemorySessionStore(
      StoredSession(
        userId: 'u-1',
        email: 'ana@correo.com',
        tokens: tokensAt(api.now),
        activeBusiness: remoteBusiness('b-1'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pulperiaApiProvider.overrideWithValue(api),
          sessionStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => api.now),
          onlineProvider.overrideWith((ref) => online.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Consumer(builder: _warm)),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('al abrir sincroniza una vez', (tester) async {
    await pumpTriggers(tester);

    expect(api.count('pull'), 1);
  });

  testWidgets('al recuperar la conexión sincroniza una vez más', (
    tester,
  ) async {
    await pumpTriggers(tester);
    api.calls.clear();

    online.add(false);
    await settle(tester);
    expect(api.count('pull'), 0);

    online.add(true);
    await settle(tester);
    expect(api.count('pull'), 1);
  });

  testWidgets('si se descartó una edición por conflicto lo avisa', (
    tester,
  ) async {
    await insertOutboxOp(
      db,
      'op-1',
      'b-1',
      type: 'client.update',
      entityId: 'c-1',
      baseVersion: 1,
    );
    api.pushResult = (op) => OperationResult(
      opId: op.opId,
      status: OperationStatus.rejected,
      code: 'version_conflict',
    );

    await pumpTriggers(tester);

    expect(find.text(Strings.conflictsDiscarded(1)), findsOne);
  });

  testWidgets('seguir con conexión no vuelve a sincronizar', (tester) async {
    await pumpTriggers(tester);
    online.add(true);
    await settle(tester);
    api.calls.clear();

    online.add(true);
    await settle(tester);

    expect(api.count('pull'), 0);
  });
}

Widget _warm(BuildContext context, WidgetRef ref, Widget? _) {
  // Espera a que la sesión se lea antes de montar los disparadores.
  final session = ref.watch(sessionControllerProvider);
  return session.hasValue
      ? const SyncTriggers(child: SizedBox())
      : const SizedBox();
}
