import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/ledger/subtotal.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

import '../../support/shared_vectors.dart';

void main() {
  group('wholeLempiraSubtotal con los vectores compartidos (RF-34)', () {
    final cases = loadVectorCases('subtotal-integer.json');

    test('hay al menos 10 casos', () {
      expect(cases.length, greaterThanOrEqualTo(10));
    });

    for (final c in cases) {
      test(c.name, () {
        final subtotal = wholeLempiraSubtotal(
          quantity: Quantity(c.input['quantityMilli'] as int),
          unitPrice: Money(c.input['unitPrice'] as int),
        );

        expect(subtotal.minorUnits, c.expected['subtotal']);
      });
    }
  });

  group('wholeLempiraSubtotal, propiedades', () {
    test('el resultado siempre es un lempira entero y dista a lo sumo medio lempira del valor exacto', () {
      for (var milli = 1; milli <= 5000; milli += 7) {
        for (final price in [100, 500, 1200, 2500, 9900, 100000]) {
          final subtotal = wholeLempiraSubtotal(
            quantity: Quantity(milli),
            unitPrice: Money(price),
          ).minorUnits;
          final exactTimes1000 = milli * price;

          expect(subtotal % 100, 0, reason: 'milli=$milli price=$price');
          expect(
            (subtotal * 1000 - exactTimes1000).abs() <= 50 * 1000,
            isTrue,
            reason: 'milli=$milli price=$price',
          );
        }
      }
    });

    test('una cantidad entera da exactamente cantidad por precio', () {
      expect(
        wholeLempiraSubtotal(
          quantity: const Quantity(7000),
          unitPrice: const Money(1300),
        ),
        const Money(9100),
      );
    });

    test('el resultado no disminuye cuando crece la cantidad', () {
      var previous = 0;
      for (var milli = 1; milli <= 3000; milli++) {
        final current = wholeLempiraSubtotal(
          quantity: Quantity(milli),
          unitPrice: const Money(3000),
        ).minorUnits;

        expect(current >= previous, isTrue, reason: 'milli=$milli');
        previous = current;
      }
    });
  });
}
