import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/ui/format/money_format.dart';

void main() {
  group('con 2 decimales', () {
    const mode = AmountMode.twoDecimals;

    test('muestra lempiras y centavos', () {
      expect(formatMoney(const Money(12345), mode), 'L 123.45');
      expect(formatMoney(const Money(5), mode), 'L 0.05');
      expect(formatMoney(Money.zero, mode), 'L 0.00');
    });

    test('separa los miles con coma', () {
      expect(formatMoney(const Money(123456789), mode), 'L 1,234,567.89');
      expect(formatMoney(const Money(100000), mode), 'L 1,000.00');
      expect(formatMoney(const Money(99900), mode), 'L 999.00');
    });

    test('un negativo lleva signo', () {
      expect(formatMoney(const Money(-250), mode), '-L 2.50');
    });
  });

  group('con enteros', () {
    const mode = AmountMode.integer;

    test('no muestra decimales', () {
      expect(formatMoney(const Money(15000), mode), 'L 150');
      expect(formatMoney(const Money(123400), mode), 'L 1,234');
      expect(formatMoney(Money.zero, mode), 'L 0');
    });
  });
}
