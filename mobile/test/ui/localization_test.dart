import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';

import '../support/db_fixtures.dart';
import '../support/fake_api.dart';
import '../support/dev_session.dart';

void main() {
  testWidgets('los textos propios de Flutter salen en español', (tester) async {
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

    final context = tester.element(find.byType(Scaffold).first);
    final l10n = MaterialLocalizations.of(context);
    expect(l10n.backButtonTooltip, 'Atrás');
    expect(l10n.pasteButtonLabel.toLowerCase(), 'pegar');
    expect(l10n.cancelButtonLabel.toLowerCase(), 'cancelar');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).supportedLocales,
      const [Locale('es')],
    );
  });
}
