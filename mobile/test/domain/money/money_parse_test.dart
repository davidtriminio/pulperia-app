import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/shared_vectors.dart';

void main() {
  group('AmountMode', () {
    test('se identifica con los mismos ids que los vectores compartidos', () {
      expect(AmountMode.fromId('integer'), AmountMode.integer);
      expect(AmountMode.fromId('two_decimals'), AmountMode.twoDecimals);
    });

    test('un id desconocido lanza ArgumentError', () {
      expect(() => AmountMode.fromId('otro'), throwsArgumentError);
    });
  });

  group('Money.parse con los vectores compartidos (RF-32, RF-36)', () {
    final cases = loadVectorCases('business-modes.json')
        .where((c) => c.input['operation'] == 'validate_amount')
        .toList();

    test('hay casos de monto en los vectores', () {
      expect(cases.length, greaterThanOrEqualTo(10));
    });

    for (final c in cases) {
      test(c.name, () {
        final mode = AmountMode.fromId(c.input['amountMode'] as String);

        final result = Money.parse(c.input['text'] as String, mode);

        if (c.expected['valid'] == true) {
          expect(result, isA<MoneyParsed>());
          expect((result as MoneyParsed).money.minorUnits, c.expected['value']);
        } else {
          expect(result, isA<MoneyRejected>());
          expect((result as MoneyRejected).error.code, c.expected['error']);
        }
      });
    }
  });

  group('Money.parse con texto que no es un número', () {
    for (final text in [
      '',
      'abc',
      '12,50',
      '12.',
      '.5',
      '--1',
      '1e3',
      ' 12',
      '12 ',
    ]) {
      test('"$text" se rechaza sin lanzar excepción', () {
        for (final mode in AmountMode.values) {
          final result = Money.parse(text, mode);

          expect(result, isA<MoneyRejected>());
          expect((result as MoneyRejected).error, AmountError.invalidFormat);
        }
      });
    }
  });

  group('Money.parse, casos que la spec no define', () {
    test('en modo entero, "12.00" vale L 12 porque no tiene fracción', () {
      final result = Money.parse('12.00', AmountMode.integer);

      expect((result as MoneyParsed).money, const Money(1200));
    });

    test('en modo entero, "12.005" se rechaza por tener fracción', () {
      final result = Money.parse('12.005', AmountMode.integer);

      expect((result as MoneyRejected).error, AmountError.notWhole);
    });

    test('en modo de 2 decimales, más de 2 decimales se rechaza', () {
      for (final text in ['12.505', '0.001', '1.999']) {
        final result = Money.parse(text, AmountMode.twoDecimals);

        expect(
          (result as MoneyRejected).error,
          AmountError.tooManyDecimals,
          reason: text,
        );
      }
    });

    test('un monto no positivo se rechaza antes que cualquier otra regla', () {
      final result = Money.parse('-12.505', AmountMode.twoDecimals);

      expect((result as MoneyRejected).error, AmountError.notPositive);
    });

    test('un monto grande no pierde exactitud', () {
      final result = Money.parse('999999999.99', AmountMode.twoDecimals);

      expect((result as MoneyParsed).money.minorUnits, 99999999999);
    });
  });
}
