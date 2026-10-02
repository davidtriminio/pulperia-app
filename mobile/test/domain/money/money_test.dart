import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

void main() {
  group('Money', () {
    test('guarda el monto en la unidad menor (centavos de lempira)', () {
      expect(const Money(3000).minorUnits, 3000);
    });

    test('zero vale cero', () {
      expect(Money.zero.minorUnits, 0);
      expect(Money.zero.isZero, isTrue);
    });

    test(
      'dos montos con el mismo valor son iguales y tienen el mismo hash',
      () {
        expect(const Money(1250), const Money(1250));
        expect(const Money(1250).hashCode, const Money(1250).hashCode);
        expect(const Money(1250), isNot(const Money(1251)));
      },
    );

    test('suma', () {
      expect(const Money(1250) + const Money(750), const Money(2000));
      expect(Money.zero + const Money(5), const Money(5));
    });

    test('resta, y puede quedar negativa (saldo a favor)', () {
      expect(const Money(10000) - const Money(3000), const Money(7000));
      expect(const Money(10000) - const Money(12000), const Money(-2000));
    });

    test('negación', () {
      expect(-const Money(500), const Money(-500));
      expect(-Money.zero, Money.zero);
    });

    test('isPositive, isNegative e isZero', () {
      expect(const Money(1).isPositive, isTrue);
      expect(const Money(1).isNegative, isFalse);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(-1).isPositive, isFalse);
      expect(const Money(0).isZero, isTrue);
      expect(const Money(0).isPositive, isFalse);
      expect(const Money(0).isNegative, isFalse);
    });

    test('operadores de comparación', () {
      expect(const Money(100) < const Money(200), isTrue);
      expect(const Money(200) > const Money(100), isTrue);
      expect(const Money(100) <= const Money(100), isTrue);
      expect(const Money(100) >= const Money(100), isTrue);
      expect(const Money(100) < const Money(100), isFalse);
      expect(const Money(-1) < Money.zero, isTrue);
    });

    test('compareTo permite ordenar de menor a mayor', () {
      final sorted = [const Money(300), const Money(-50), const Money(100)]
        ..sort();

      expect(sorted, [const Money(-50), const Money(100), const Money(300)]);
    });

    test('sumar un millón de centavos uno a uno es exacto, sin deriva', () {
      var total = Money.zero;
      for (var i = 0; i < 1000000; i++) {
        total += const Money(1);
      }

      expect(total, const Money(1000000));
    });

    test('sumar valores grandes es exacto', () {
      const big = Money(99999999000);

      expect(big + big + big, const Money(299999997000));
    });

    test('toString muestra la unidad menor, útil para depurar', () {
      expect(const Money(1250).toString(), 'Money(1250)');
    });
  });

  group('Money (todo el dominio)', () {
    test('ningún archivo de lib/domain usa double', () {
      final files = Directory('lib/domain')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final offenders = [
        for (final f in files)
          if (RegExp(r'\bdouble\b').hasMatch(f.readAsStringSync())) f.path,
      ];

      expect(files, isNotEmpty);
      expect(offenders, isEmpty);
    });
  });
}
