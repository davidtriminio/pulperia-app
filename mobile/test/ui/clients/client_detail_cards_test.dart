import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

import '../../support/dev_session.dart';

import 'package:pulperia_mobile/ui/avatar/avatar_view.dart';
import 'package:pulperia_mobile/ui/clients/client_detail_screen.dart';
import 'package:pulperia_mobile/ui/theme.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late String businessId;

  setUp(() {
    db = openDb();
    businessId = devSessionFor(isRelease: false)!.businessId;
  });
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? seed,
    String name = 'Ana López',
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedDevSession(db, devSessionFor(isRelease: false));
      await insertClient(db, 'c-1', businessId, name: name);
      await seed?.call();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(devSessionFor()!),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const ClientDetailScreen(clientId: 'c-1'),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> contact({
    String? phone,
    String? address,
    String? note,
    bool archived = false,
  }) => (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
    ClientsCompanion(
      phone: Value(phone),
      address: Value(address),
      note: Value(note),
      archived: Value(archived),
    ),
  );

  Finder key(String k) => find.byKey(ValueKey(k));
  Finder inHeader(Finder f) =>
      find.descendant(of: key('detail-header'), matching: f);
  String text(WidgetTester tester, String k) =>
      tester.widget<Text>(key(k)).data!;

  group('cabecera del detalle (RF-42)', () {
    testWidgets('reúne avatar, nombre, etiqueta y saldo', (tester) async {
      await pump(
        tester,
        seed: () => insertFiado(db, 'f-1', businessId, 'c-1', total: 7000),
      );

      expect(inHeader(find.byType(AvatarView)), findsOne);
      expect(inHeader(find.text('Ana López')), findsOne);
      expect(inHeader(key('balance-label')), findsOne);
      expect(inHeader(key('balance-amount')), findsOne);
      expect(text(tester, 'balance-label'), 'Debe');
      expect(text(tester, 'balance-amount'), 'L 70.00');
    });

    testWidgets('al día muestra la etiqueta y L 0.00', (tester) async {
      await pump(tester);

      expect(text(tester, 'balance-label'), 'Al día');
      expect(text(tester, 'balance-amount'), 'L 0.00');
    });

    testWidgets('saldo a favor se distingue de la deuda', (tester) async {
      await pump(
        tester,
        seed: () => insertPayment(db, 'p-1', businessId, 'c-1', amount: 3000),
      );

      expect(text(tester, 'balance-label'), 'A favor');
      expect(text(tester, 'balance-amount'), 'L 30.00');
    });

    testWidgets('teléfono, dirección y nota son chips dentro de la cabecera', (
      tester,
    ) async {
      await pump(
        tester,
        seed: () => contact(
          phone: '90000000',
          address: 'Frente a la iglesia',
          note: 'Paga los viernes',
        ),
      );

      for (final k in ['contact-phone', 'contact-address', 'contact-note']) {
        expect(inHeader(key(k)), findsOne, reason: k);
      }
      expect(find.text('90000000'), findsOne);
      expect(find.text('Frente a la iglesia'), findsOne);
      expect(find.text('Paga los viernes'), findsOne);
    });

    testWidgets('solo salen los chips de los datos que existen', (
      tester,
    ) async {
      await pump(tester, seed: () => contact(phone: '90000000'));

      expect(key('contact-phone'), findsOne);
      expect(key('contact-address'), findsNothing);
      expect(key('contact-note'), findsNothing);
    });

    testWidgets('un archivado se marca dentro de la cabecera', (tester) async {
      await pump(tester, seed: () => contact(archived: true));

      expect(inHeader(find.text('Archivado')), findsOne);
    });

    testWidgets('un cliente activo no lleva la marca', (tester) async {
      await pump(tester);

      expect(find.text('Archivado'), findsNothing);
    });

    testWidgets('datos largos no desbordan en pantallas angostas', (
      tester,
    ) async {
      await pump(
        tester,
        width: 320,
        name: 'María de los Ángeles Fernández Gutiérrez de la Cruz',
        seed: () async {
          await contact(
            phone: '90000000',
            address:
                'Colonia Los Pinos, bloque 5, casa 12, frente a la iglesia',
            note:
                'Paga los viernes cuando le depositan, avisar antes de cobrar',
          );
          await insertFiado(db, 'f-1', businessId, 'c-1', total: 123456789);
        },
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('movimientos del historial (RF-41)', () {
    Future<void> seedMovements() async {
      await insertFiado(
        db,
        'f-1',
        businessId,
        'c-1',
        total: 5000,
        occurredAt: DateTime.utc(2026, 10, 1),
      );
      await insertFiadoItem(
        db,
        'i-1',
        businessId,
        'f-1',
        description: 'Arroz',
        quantity: 2000,
        unitPrice: 2500,
        subtotal: 5000,
      );
      await insertPayment(
        db,
        'p-1',
        businessId,
        'c-1',
        amount: 2000,
        occurredAt: DateTime.utc(2026, 10, 2),
      );
    }

    testWidgets('el fiado va con + y el abono con −', (tester) async {
      await pump(tester, seed: seedMovements);

      expect(text(tester, 'entry-amount-f-1'), '+ L 50.00');
      expect(text(tester, 'entry-amount-p-1'), '− L 20.00');
    });

    testWidgets('los ítems del fiado siguen visibles en un panel interior', (
      tester,
    ) async {
      await pump(tester, seed: seedMovements);

      final panel = find.descendant(
        of: key('entry-f-1'),
        matching: key('entry-items-f-1'),
      );
      expect(panel, findsOne);
      expect(
        find.descendant(of: panel, matching: find.text('Arroz')),
        findsOne,
      );
      expect(
        find.descendant(of: panel, matching: find.text('2 unidades × L 25.00')),
        findsOne,
      );
      expect(key('entry-items-p-1'), findsNothing);
    });

    testWidgets('un anulado sigue marcado y con su fecha', (tester) async {
      await pump(
        tester,
        seed: () async {
          await seedMovements();
          await insertFiado(
            db,
            'f-2',
            businessId,
            'c-1',
            total: 1000,
            occurredAt: DateTime.utc(2026, 10, 3),
            annulledAt: DateTime.utc(2026, 10, 4),
            annulledBy: 'u-1',
          );
        },
      );

      expect(key('annulled-f-2'), findsOne);
      expect(key('annulled-f-1'), findsNothing);
      expect(find.textContaining('Anulado el'), findsOne);
      // El anulado no cuenta en el saldo: 50 − 20 = 30.
      expect(text(tester, 'balance-amount'), 'L 30.00');
    });

    testWidgets('el monto de cada movimiento queda pegado al borde derecho', (
      tester,
    ) async {
      await pump(tester, width: 800, seed: seedMovements);

      for (final id in ['f-1', 'p-1']) {
        final tile = tester.getRect(key('entry-$id'));
        final amount = tester.getRect(key('entry-amount-$id'));
        expect(tile.right - amount.right, lessThan(24), reason: id);
      }
    });

    testWidgets('las tarjetas de movimiento llevan sombra suave', (
      tester,
    ) async {
      await pump(tester, seed: seedMovements);

      final box = tester.widget<DecoratedBox>(key('entry-f-1'));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.borderRadius, BorderRadius.circular(20));
    });
  });
}
