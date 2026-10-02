import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

import '../../support/shared_vectors.dart';

void main() {
  group('Quantity', () {
    test('guarda la cantidad en milésimas', () {
      expect(const Quantity(250).milli, 250);
    });

    test('igualdad por valor', () {
      expect(const Quantity(1500), const Quantity(1500));
      expect(const Quantity(1500).hashCode, const Quantity(1500).hashCode);
      expect(const Quantity(1500), isNot(const Quantity(1501)));
    });

    test('isWhole indica si no tiene fracción', () {
      expect(const Quantity(2000).isWhole, isTrue);
      expect(const Quantity(2500).isWhole, isFalse);
      expect(const Quantity(1).isWhole, isFalse);
    });
  });

  group('QuantityMode', () {
    test('se identifica con los mismos ids que los vectores compartidos', () {
      expect(QuantityMode.fromId('integer'), QuantityMode.integer);
      expect(QuantityMode.fromId('fractional'), QuantityMode.fractional);
    });

    test('un id desconocido lanza ArgumentError', () {
      expect(() => QuantityMode.fromId('otro'), throwsArgumentError);
    });
  });

  group(
    'Quantity.parse con los vectores compartidos (RF-32, RF-35, RF-84)',
    () {
      final cases = loadVectorCases('business-modes.json')
          .where((c) => c.input['operation'] == 'validate_quantity')
          .toList();

      test('hay casos de cantidad en los vectores', () {
        expect(cases.length, greaterThanOrEqualTo(20));
      });

      for (final c in cases) {
        test(c.name, () {
          final mode = QuantityMode.fromId(c.input['quantityMode'] as String);

          final result = Quantity.parse(c.input['text'] as String, mode);

          if (c.expected['valid'] == true) {
            expect(result, isA<QuantityParsed>());
            expect(
              (result as QuantityParsed).quantity.milli,
              c.expected['value'],
            );
          } else {
            expect(result, isA<QuantityRejected>());
            expect(
              (result as QuantityRejected).error.code,
              c.expected['error'],
            );
          }
        });
      }
    },
  );

  group('Quantity.parse con texto que no es un número', () {
    for (final text in [
      '',
      'abc',
      '1,5',
      '1.',
      '.5',
      '--1',
      '1e3',
      ' 2',
      '2 ',
    ]) {
      test('"$text" se rechaza sin lanzar excepción', () {
        for (final mode in QuantityMode.values) {
          final result = Quantity.parse(text, mode);

          expect(result, isA<QuantityRejected>());
          expect(
            (result as QuantityRejected).error,
            QuantityError.invalidFormat,
          );
        }
      });
    }
  });

  group('Quantity.parse, casos adicionales', () {
    test('en modo entero, "2.0" vale 2 porque no tiene fracción', () {
      final result = Quantity.parse('2.0', QuantityMode.integer);

      expect((result as QuantityParsed).quantity, const Quantity(2000));
    });

    test('en modo fraccionario, "-0" no es positivo', () {
      final result = Quantity.parse('-0', QuantityMode.fractional);

      expect((result as QuantityRejected).error, QuantityError.notPositive);
    });

    test('una cantidad entera muy grande no pierde exactitud', () {
      final result = Quantity.parse('9999999', QuantityMode.integer);

      expect((result as QuantityParsed).quantity.milli, 9999999000);
    });
  });
}
