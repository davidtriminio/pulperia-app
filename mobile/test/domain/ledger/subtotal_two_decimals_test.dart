import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/ledger/subtotal.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

import '../../support/shared_vectors.dart';

void main() {
  group('centavoSubtotal con los vectores compartidos (RF-83)', () {
    final cases = loadVectorCases('subtotal-two-decimals.json');

    test('hay al menos 10 casos', () {
      expect(cases.length, greaterThanOrEqualTo(10));
    });

    for (final c in cases) {
      test(c.name, () {
        final subtotal = centavoSubtotal(
          quantity: Quantity(c.input['quantityMilli'] as int),
          unitPrice: Money(c.input['unitPrice'] as int),
        );

        expect(subtotal.minorUnits, c.expected['subtotal']);
      });
    }
  });

  group('centavoSubtotal, propiedades', () {
    test('el resultado dista a lo sumo medio centavo del valor exacto', () {
      for (var milli = 1; milli <= 5000; milli += 7) {
        for (final price in [1, 99, 500, 1001, 1250, 123456, 99999999]) {
          final subtotal = centavoSubtotal(
            quantity: Quantity(milli),
            unitPrice: Money(price),
          ).minorUnits;
          final exactTimes1000 = milli * price;

          expect(
            (subtotal * 1000 - exactTimes1000).abs() <= 500,
            isTrue,
            reason: 'milli=$milli price=$price',
          );
        }
      }
    });

    test('una cantidad entera da exactamente cantidad por precio', () {
      expect(
        centavoSubtotal(
          quantity: const Quantity(7000),
          unitPrice: const Money(1299),
        ),
        const Money(9093),
      );
    });

    test('el resultado no disminuye cuando crece la cantidad', () {
      var previous = 0;
      for (var milli = 1; milli <= 3000; milli++) {
        final current = centavoSubtotal(
          quantity: Quantity(milli),
          unitPrice: const Money(1250),
        ).minorUnits;

        expect(current >= previous, isTrue, reason: 'milli=$milli');
        previous = current;
      }
    });

    test('con un precio en lempiras enteros y cantidad entera coincide con el modo entero', () {
      for (var units = 1; units <= 50; units++) {
        final quantity = Quantity(units * 1000);
        const price = Money(2500);

        expect(
          centavoSubtotal(quantity: quantity, unitPrice: price),
          wholeLempiraSubtotal(quantity: quantity, unitPrice: price),
        );
      }
    });
  });
}
