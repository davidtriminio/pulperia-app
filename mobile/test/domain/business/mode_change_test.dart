import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/mode_change.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';

import '../../support/shared_vectors.dart';

void main() {
  group('cambio de modo con los vectores compartidos (RF-8, RF-9)', () {
    final cases = loadVectorCases('business-modes.json')
        .where(
          (c) =>
              c.input['operation'] == 'change_amount_mode' ||
              c.input['operation'] == 'change_quantity_mode',
        )
        .toList();

    test('hay casos de cambio de modo en los vectores', () {
      expect(cases.length, 8);
    });

    for (final c in cases) {
      test(c.name, () {
        final ModeChangeResult result;
        if (c.input['operation'] == 'change_amount_mode') {
          result = changeAmountMode(
            current: AmountMode.fromId(c.input['current'] as String),
            requested: AmountMode.fromId(c.input['requested'] as String),
          );
        } else {
          result = changeQuantityMode(
            current: QuantityMode.fromId(c.input['current'] as String),
            requested: QuantityMode.fromId(c.input['requested'] as String),
          );
        }

        if (c.expected['allowed'] == true) {
          expect(result, isA<ModeChangeAllowed>());
        } else {
          expect(result, isA<ModeChangeDenied>());
          expect((result as ModeChangeDenied).error.code, c.expected['error']);
        }
      });
    }
  });

  group('cambio de modo, todas las combinaciones', () {
    test('montos: solo se rechaza pasar de 2 decimales a enteros', () {
      for (final current in AmountMode.values) {
        for (final requested in AmountMode.values) {
          final result = changeAmountMode(
            current: current,
            requested: requested,
          );
          final isDowngrade =
              current == AmountMode.twoDecimals &&
              requested == AmountMode.integer;

          expect(
            result is ModeChangeDenied,
            isDowngrade,
            reason: '$current -> $requested',
          );
        }
      }
    });

    test('cantidades: solo se rechaza pasar de fraccionarias a enteras', () {
      for (final current in QuantityMode.values) {
        for (final requested in QuantityMode.values) {
          final result = changeQuantityMode(
            current: current,
            requested: requested,
          );
          final isDowngrade =
              current == QuantityMode.fractional &&
              requested == QuantityMode.integer;

          expect(
            result is ModeChangeDenied,
            isDowngrade,
            reason: '$current -> $requested',
          );
        }
      }
    });
  });
}
