import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/sync/sync_indicator.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;

  setUp(() async {
    db = openDb();
    api = FakeApi();
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2', name: 'Otro');
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpIndicator(WidgetTester tester) async {
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
          syncWaitProvider.overrideWithValue((_) async {}),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Consumer(builder: _gate)),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('sin pendientes no se ve', (tester) async {
    await pumpIndicator(tester);

    expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
  });

  testWidgets('con pendientes del negocio activo dice cuántos', (tester) async {
    await insertOutboxOp(db, 'op-1', 'b-1');
    await insertOutboxOp(db, 'op-2', 'b-1', entityId: 'c-2');
    await insertOutboxOp(db, 'op-3', 'b-2', entityId: 'c-3');

    await pumpIndicator(tester);

    expect(find.text(Strings.pendingChanges(2)), findsOne);
  });

  testWidgets('aparece al guardar algo y desaparece al vaciarse la cola', (
    tester,
  ) async {
    await pumpIndicator(tester);
    expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);

    await tester.runAsync(() => insertOutboxOp(db, 'op-1', 'b-1'));
    await settle(tester);
    expect(find.text(Strings.pendingChanges(1)), findsOne);

    await tester.runAsync(() => db.delete(db.outboxOps).go());
    await settle(tester);
    expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
  });

  testWidgets('un toque sincroniza y, al enviarse todo, se va', (tester) async {
    await insertOutboxOp(db, 'op-1', 'b-1');
    await pumpIndicator(tester);

    await tester.tap(find.byKey(const ValueKey('sync-indicator')));
    await settle(tester);

    expect(api.count('push'), 1);
    expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
  });

  testWidgets('sin sesión utilizable pide iniciar sesión para sincronizar', (
    tester,
  ) async {
    await insertOutboxOp(db, 'op-1', 'b-1');
    await pumpIndicator(tester);
    // El token de renovación caducó mientras no había conexión.
    api.now = api.now.add(const Duration(days: 100));

    await tester.tap(find.byKey(const ValueKey('sync-indicator')));
    await settle(tester);

    expect(find.text(Strings.syncNeedsLogin), findsOne);
  });
}

Widget _gate(BuildContext context, WidgetRef ref, Widget? _) {
  final session = ref.watch(sessionControllerProvider);
  return session.hasValue ? const SyncIndicator() : const SizedBox();
}
