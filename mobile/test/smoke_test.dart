import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';

import 'support/db_fixtures.dart';
import 'support/fake_api.dart';
import 'support/dev_session.dart';

void main() {
  testWidgets('la app arranca dentro de un MaterialApp', (tester) async {
    final db = openDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pulperiaApiProvider.overrideWithValue(FakeApi()),
          syncWaitProvider.overrideWithValue((_) async {}),
          activeSessionProvider.overrideWithValue(devSessionFor()!),
        ],
        child: const PulperiaApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
