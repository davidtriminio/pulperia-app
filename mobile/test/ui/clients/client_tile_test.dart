import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/ui/clients/client_tile.dart';
import 'package:pulperia_mobile/ui/theme.dart';

void main() {
  final created = DateTime.utc(2026, 10, 2);

  ClientWithBalance item(
    String id,
    int balanceCents, {
    String name = 'Ana',
    bool archived = false,
  }) => ClientWithBalance(
    Client(
      id: id,
      businessId: 'b-1',
      name: name,
      characterId: 'char-01',
      skinId: 'skin-1',
      backgroundId: 'bg-01',
      archived: archived,
      version: 1,
      createdBy: 'u-1',
      createdAt: created,
      updatedAt: created,
    ),
    Balance(Money(balanceCents)),
  );

  Future<void> pump(
    WidgetTester tester,
    List<ClientWithBalance> items, {
    VoidCallback? onTap,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ListView(
            children: [
              for (final i in items)
                ClientTile(
                  item: i,
                  amountMode: AmountMode.twoDecimals,
                  onTap: onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  Text label(WidgetTester tester, String id) =>
      tester.widget<Text>(key('balance-label-$id'));

  group('tarjeta de cliente (RF-42)', () {
    testWidgets('la deuda se muestra en rojo con su monto', (tester) async {
      await pump(tester, [item('c-1', 7000)]);

      expect(label(tester, 'c-1').data, 'Debe');
      expect(label(tester, 'c-1').style?.color, AppColors.debt);
      expect(tester.widget<Text>(key('balance-amount-c-1')).data, 'L 70.00');
      expect(key('balance-chip-c-1'), findsOne);
    });

    testWidgets('el saldo a favor se muestra en verde azulado', (tester) async {
      await pump(tester, [item('c-1', -3000)]);

      expect(label(tester, 'c-1').data, 'A favor');
      expect(label(tester, 'c-1').style?.color, AppColors.credit);
      expect(tester.widget<Text>(key('balance-amount-c-1')).data, 'L 30.00');
    });

    testWidgets('el saldo en cero dice "Al día" y no muestra monto', (
      tester,
    ) async {
      await pump(tester, [item('c-1', 0)]);

      expect(label(tester, 'c-1').data, 'Al día');
      expect(key('balance-amount-c-1'), findsNothing);
    });

    testWidgets('la etiqueta va en una píldora tintada del color del saldo', (
      tester,
    ) async {
      await pump(tester, [item('c-1', 7000), item('c-2', -3000)]);

      Color chipColor(String id) =>
          (tester.widget<Container>(key('balance-chip-$id')).decoration!
                  as BoxDecoration)
              .color!;
      expect(chipColor('c-1'), AppColors.debt.withValues(alpha: 0.12));
      expect(chipColor('c-2'), AppColors.credit.withValues(alpha: 0.12));
    });
  });

  group('estado archivado (RF-20, RF-22)', () {
    testWidgets('un archivado muestra la marca "Archivado"', (tester) async {
      await pump(tester, [item('c-1', 7000, archived: true)]);

      expect(key('archived-badge-c-1'), findsOne);
      expect(find.text('Archivado'), findsOne);
    });

    testWidgets('un cliente activo no la muestra', (tester) async {
      await pump(tester, [item('c-1', 7000)]);

      expect(key('archived-badge-c-1'), findsNothing);
    });

    testWidgets('un archivado conserva su saldo visible', (tester) async {
      await pump(tester, [item('c-1', 7000, archived: true)]);

      expect(label(tester, 'c-1').data, 'Debe');
      expect(tester.widget<Text>(key('balance-amount-c-1')).data, 'L 70.00');
    });
  });

  group('forma de la tarjeta', () {
    testWidgets('todas las tarjetas tienen la misma altura', (tester) async {
      await pump(tester, [
        item('c-1', 7000),
        item('c-2', -3000),
        item('c-3', 0),
        item('c-4', 7000, archived: true),
      ]);

      final heights = {
        for (final id in ['c-1', 'c-2', 'c-3', 'c-4'])
          tester.getSize(key('client-tile-$id')).height,
      };
      expect(heights.length, 1);
    });

    testWidgets('un nombre muy largo no desborda en pantallas angostas', (
      tester,
    ) async {
      await pump(tester, [
        item(
          'c-1',
          123456789,
          name: 'María de los Ángeles Fernández Gutiérrez',
        ),
        item('c-2', 7000, name: 'Beto Largo Largo Largo Largo', archived: true),
      ], width: 320);

      expect(tester.takeException(), isNull);
    });

    testWidgets('un toque abre el detalle', (tester) async {
      var taps = 0;
      await pump(tester, [item('c-1', 7000)], onTap: () => taps++);

      await tester.tap(key('client-tile-c-1'));

      expect(taps, 1);
    });
  });
}
