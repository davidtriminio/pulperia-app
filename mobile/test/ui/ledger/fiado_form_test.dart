import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
import 'package:pulperia_mobile/ui/ledger/fiado_form_screen.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late DevSession session;

  setUp(() {
    db = openDb();
    session = devSessionFor(isRelease: false)!;
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  /// Abre el formulario desde otra pantalla, para ver que se cierra al guardar.
  Future<void> openForm(
    WidgetTester tester, {
    String amountMode = 'two_decimals',
    String quantityMode = 'fractional',
    bool archived = false,
    Future<void> Function()? seed,
  }) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await (db.update(
        db.businesses,
      )..where((b) => b.id.equals(session.businessId))).write(
        BusinessesCompanion(
          amountMode: Value(amountMode),
          quantityMode: Value(quantityMode),
        ),
      );
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
      if (archived) {
        await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
          const ClientsCompanion(archived: Value(true)),
        );
      }
      await seed?.call();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FiadoFormScreen(clientId: 'c-1'),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  Future<void> fillItem(
    WidgetTester tester,
    int index, {
    String? description,
    String? quantity,
    String? price,
  }) async {
    Future<void> enter(String key, String? text) async {
      if (text == null) return;
      final finder = find.byKey(ValueKey('$key-$index'));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, text);
      await tester.pump();
    }

    await enter('item-description', description);
    await enter('item-quantity', quantity);
    await enter('item-price', price);
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('fiado-save'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<List<Fiado>> fiados(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiados).get()))!;

  Future<List<FiadoItem>> items(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.fiadoItems).get()))!;

  group('ítems', () {
    testWidgets('arranca con un ítem vacío con cantidad 1', (tester) async {
      await openForm(tester);

      expect(find.byKey(const ValueKey('item-quantity-0')), findsOne);
      final quantity = tester.widget<TextField>(
        find.byKey(const ValueKey('item-quantity-0')),
      );
      expect(quantity.controller!.text, '1');
      expect(find.byKey(const ValueKey('item-quantity-1')), findsNothing);
    });

    testWidgets('se pueden agregar y quitar ítems', (tester) async {
      await openForm(tester);

      await tester.tap(find.byKey(const ValueKey('add-item')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('item-quantity-1')), findsOne);

      await tester.ensureVisible(find.byKey(const ValueKey('remove-item-1')));
      await tester.tap(find.byKey(const ValueKey('remove-item-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('item-quantity-1')), findsNothing);
    });

    testWidgets('con un solo ítem no hay botón para quitarlo', (tester) async {
      await openForm(tester);

      expect(find.byKey(const ValueKey('remove-item-0')), findsNothing);
    });
  });

  group('subtotal y total redondeados según el modo (RF-34, RF-83)', () {
    testWidgets('con 2 decimales redondea al centavo', (tester) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: '0.333', price: '12.50');

      expect(text(tester, 'item-subtotal-0'), 'L 4.16');
      expect(text(tester, 'fiado-total'), 'L 4.16');
    });

    testWidgets('con montos enteros redondea al lempira, la mitad sube', (
      tester,
    ) async {
      await openForm(tester, amountMode: 'integer');

      await fillItem(tester, 0, quantity: '0.5', price: '25');

      expect(text(tester, 'item-subtotal-0'), 'L 13');
      expect(text(tester, 'fiado-total'), 'L 13');
    });

    testWidgets('el total suma los subtotales ya redondeados', (tester) async {
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('add-item')));
      await tester.pumpAndSettle();

      await fillItem(tester, 0, quantity: '3', price: '2.50');
      await fillItem(tester, 1, quantity: '0.333', price: '12.50');

      expect(text(tester, 'item-subtotal-0'), 'L 7.50');
      expect(text(tester, 'item-subtotal-1'), 'L 4.16');
      expect(text(tester, 'fiado-total'), 'L 11.66');
    });

    testWidgets('sin datos completos el subtotal no se muestra', (
      tester,
    ) async {
      await openForm(tester);

      expect(find.byKey(const ValueKey('item-subtotal-0')), findsNothing);
      expect(text(tester, 'fiado-total'), 'L 0.00');
    });
  });

  group('registrar el fiado (RF-28, RF-33)', () {
    testWidgets('guarda el fiado con su detalle y se cierra', (tester) async {
      await openForm(tester);
      await tester.tap(find.byKey(const ValueKey('add-item')));
      await tester.pumpAndSettle();

      await fillItem(
        tester,
        0,
        description: 'Arroz',
        quantity: '2',
        price: '25',
      );
      await fillItem(
        tester,
        1,
        description: 'Sal',
        quantity: '0.5',
        price: '10',
      );
      await save(tester);

      final saved = (await fiados(tester)).single;
      expect(saved.clientId, 'c-1');
      expect(saved.total, 5500);
      expect(saved.createdBy, session.userId);
      final saved2 = await items(tester);
      expect(saved2, hasLength(2));
      expect(saved2.map((i) => i.description), containsAll(['Arroz', 'Sal']));
      expect(saved2.firstWhere((i) => i.description == 'Arroz').quantity, 2000);
      expect(saved2.firstWhere((i) => i.description == 'Sal').unitPrice, 1000);
      expect(find.byType(FiadoFormScreen), findsNothing);
    });

    testWidgets('la descripción no se valida: un ítem sin ella se guarda', (
      tester,
    ) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: '1', price: '5');
      await save(tester);

      expect((await items(tester)).single.description, '');
    });

    testWidgets('la cantidad debe ser mayor que cero', (tester) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: '0', price: '5');
      await save(tester);

      expect(find.text(Strings.quantityNotPositive), findsOne);
      expect(await fiados(tester), isEmpty);
    });

    testWidgets('una cantidad que no es número se rechaza', (tester) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: 'dos', price: '5');
      await save(tester);

      expect(find.text(Strings.quantityInvalid), findsOne);
    });

    testWidgets('más de 3 decimales en la cantidad se rechaza (RF-84)', (
      tester,
    ) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: '1.2345', price: '5');
      await save(tester);

      expect(find.text(Strings.quantityTooManyDecimals), findsOne);
    });

    testWidgets('con cantidades enteras no se aceptan fracciones (RF-35)', (
      tester,
    ) async {
      await openForm(tester, quantityMode: 'integer');

      await fillItem(tester, 0, quantity: '0.5', price: '5');
      await save(tester);

      expect(find.text(Strings.quantityNotWhole), findsOne);
      expect(await fiados(tester), isEmpty);
    });

    testWidgets('sin precio pide indicarlo', (tester) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: '1');
      await save(tester);

      expect(find.text(Strings.priceRequired), findsOne);
      expect(await fiados(tester), isEmpty);
    });

    testWidgets('un precio de cero se rechaza', (tester) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: '1', price: '0');
      await save(tester);

      expect(find.text(Strings.amountNotPositive), findsOne);
    });

    testWidgets('con montos enteros no se aceptan centavos (RF-36)', (
      tester,
    ) async {
      await openForm(tester, amountMode: 'integer');

      await fillItem(tester, 0, quantity: '1', price: '5.50');
      await save(tester);

      expect(find.text(Strings.amountNotWhole), findsOne);
    });

    testWidgets('un subtotal que redondea a cero se rechaza', (tester) async {
      await openForm(tester);

      await fillItem(tester, 0, quantity: '0.001', price: '0.01');
      await save(tester);

      expect(find.text(Strings.subtotalZero), findsOne);
      expect(await fiados(tester), isEmpty);
    });

    testWidgets('el error de un ítem no impide corregirlo y guardar', (
      tester,
    ) async {
      await openForm(tester);
      await fillItem(tester, 0, quantity: '0', price: '5');
      await save(tester);
      expect(find.text(Strings.quantityNotPositive), findsOne);

      await fillItem(tester, 0, quantity: '2');
      await save(tester);

      expect((await fiados(tester)).single.total, 1000);
      expect(find.byType(FiadoFormScreen), findsNothing);
    });

    testWidgets('a un cliente archivado no se le fía (RF-76)', (tester) async {
      await openForm(tester, archived: true);

      await fillItem(tester, 0, quantity: '1', price: '5');
      await save(tester);

      expect(find.text(Strings.clientArchivedFiado), findsOne);
      expect(await fiados(tester), isEmpty);
      expect(find.byType(FiadoFormScreen), findsOne);
    });
  });

  testWidgets('el detalle del cliente ofrece registrar un fiado', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
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
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('register-fiado')));
    await tester.pumpAndSettle();

    expect(find.byType(FiadoFormScreen), findsOne);
  });

  testWidgets('tras guardar, el saldo del detalle se actualiza', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedDevSession(db, session);
      await insertClient(db, 'c-1', session.businessId, name: 'Ana');
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
    await settle(tester);
    expect(text(tester, 'balance-label'), Strings.balanceSettled);

    await tester.tap(find.byKey(const ValueKey('register-fiado')));
    await tester.pumpAndSettle();
    await fillItem(tester, 0, quantity: '2', price: '30');
    await save(tester);

    expect(text(tester, 'balance-label'), Strings.balanceDebt);
    expect(text(tester, 'balance-amount'), 'L 60.00');
  });
}
