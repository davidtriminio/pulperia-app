import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

import '../support/db_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openDb());
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(
      () => seedDevSession(db, devSessionFor(isRelease: false)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const PulperiaApp(),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  Iterable<String> visibleTexts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

  testWidgets('arranca en Clientes y muestra el negocio activo', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text(devSessionFor(isRelease: false)!.businessName), findsOne);
    expect(find.text(Strings.clients), findsWidgets);
  });

  testWidgets('la navegación llega a cada sección', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('nav-catalog')));
    await tester.pump();
    expect(find.byKey(const ValueKey('section-catalog')), findsOne);
    expect(find.byKey(const ValueKey('section-clients')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-clients')));
    await tester.pump();
    expect(find.byKey(const ValueKey('section-clients')), findsOne);
  });

  testWidgets('todo texto visible está en español', (tester) async {
    await pumpApp(tester);
    final allowed = {
      Strings.clients,
      Strings.catalog,
      Strings.clientsEmpty,
      Strings.archivedClientsAction,
      Strings.summary,
      Strings.summaryDebtTotal,
      Strings.summaryCreditTotal,
      Strings.summaryTopDebtors,
      Strings.summaryNoDebtors,
      'L 0.00',
      Strings.newClient,
      Strings.newProduct,
      Strings.catalogEmpty,
      devSessionFor(isRelease: false)!.businessName,
    };

    for (final key in const ['nav-clients', 'nav-summary', 'nav-catalog']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      for (final text in visibleTexts(tester)) {
        expect(allowed, contains(text), reason: 'texto inesperado: $text');
      }
    }
  });

  testWidgets('la app declara el idioma español', (tester) async {
    await pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('es'));
    expect(app.title, Strings.appTitle);
  });
}
