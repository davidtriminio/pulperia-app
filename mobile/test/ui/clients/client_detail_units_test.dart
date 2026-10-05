import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DevSession session;

  setUp(() {
    db = openDb();
    session = devSessionFor(isRelease: false)!;
  });
  tearDown(() => db.close());

  Future<void> pumpDetail(
    WidgetTester tester,
    List<({String id, String unit, int quantity, int price})> items,
  ) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      await insertFiado(db, 'f-1', session.businessId, 'c-1', total: 100000);
      for (final item in items) {
        await insertFiadoItem(
          db,
          item.id,
          session.businessId,
          'f-1',
          description: 'Producto ${item.id}',
          quantity: item.quantity,
          unitPrice: item.price,
          subtotal: 100,
        );
        await (db.update(db.fiadoItems)..where((i) => i.id.equals(item.id)))
            .write(FiadoItemsCompanion(unit: Value(item.unit)));
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          locale: Locale('es'),
          supportedLocales: [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ClientDetailScreen(clientId: 'c-1'),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }

  testWidgets('una cantidad mayor que uno va con la unidad en plural', (
    tester,
  ) async {
    await pumpDetail(tester, [
      (id: 'i-1', unit: 'pound', quantity: 2500, price: 2500),
    ]);

    expect(find.text('2.5 libras × L 25.00'), findsOne);
  });

  testWidgets('exactamente una unidad va en singular', (tester) async {
    await pumpDetail(tester, [
      (id: 'i-1', unit: 'pound', quantity: 1000, price: 9000),
    ]);

    expect(find.text('1 libra × L 90.00'), findsOne);
  });

  testWidgets('menos de una unidad también va en plural', (tester) async {
    await pumpDetail(tester, [
      (id: 'i-1', unit: 'dozen', quantity: 500, price: 6000),
    ]);

    expect(find.text('0.5 docenas × L 60.00'), findsOne);
  });

  testWidgets('los ítems anteriores a la migración muestran "unidad"', (
    tester,
  ) async {
    await pumpDetail(tester, [
      (id: 'i-1', unit: 'unit', quantity: 1000, price: 2500),
      (id: 'i-2', unit: 'unit', quantity: 3000, price: 1000),
    ]);

    expect(find.text('1 unidad × L 25.00'), findsOne);
    expect(find.text('3 unidades × L 10.00'), findsOne);
  });

  testWidgets('cada ítem del mismo fiado muestra su propia unidad', (
    tester,
  ) async {
    await pumpDetail(tester, [
      (id: 'i-1', unit: 'gallon', quantity: 2000, price: 8000),
      (id: 'i-2', unit: 'box', quantity: 1000, price: 15000),
      (id: 'i-3', unit: 'bag', quantity: 4000, price: 500),
    ]);

    expect(find.text('2 galones × L 80.00'), findsOne);
    expect(find.text('1 caja × L 150.00'), findsOne);
    expect(find.text('4 bolsas × L 5.00'), findsOne);
  });
}
