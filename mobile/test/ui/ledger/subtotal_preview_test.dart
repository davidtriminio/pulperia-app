import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/ui/ledger/subtotal_preview.dart';

Money? preview(
  String quantity,
  String price, {
  AmountMode amount = AmountMode.twoDecimals,
  QuantityMode qty = QuantityMode.fractional,
}) => previewSubtotal(
  quantity: quantity,
  unitPrice: price,
  amountMode: amount,
  quantityMode: qty,
);

void main() {
  group('con 2 decimales redondea al centavo, la mitad hacia arriba', () {
    test('cantidad entera', () {
      expect(preview('3', '2.50'), const Money(750));
    });
    test('cantidad con fracción', () {
      expect(preview('0.333', '12.50'), const Money(416)); // 4.1625
    });
    test('la mitad de un centavo sube', () {
      expect(preview('0.5', '0.01'), const Money(1)); // 0.005
    });
  });

  group('con montos enteros redondea al lempira', () {
    test('la mitad sube', () {
      expect(
        preview('0.5', '25', amount: AmountMode.integer),
        const Money(1300), // 12.5 -> 13
      );
    });
    test('por debajo de la mitad baja', () {
      expect(
        preview('0.499', '25', amount: AmountMode.integer),
        const Money(1200), // 12.475 -> 12
      );
    });
  });

  group('sin vista previa cuando no se puede calcular', () {
    test('campos vacíos', () {
      expect(preview('', '10'), isNull);
      expect(preview('1', ''), isNull);
    });
    test('texto que no es número', () {
      expect(preview('abc', '10'), isNull);
      expect(preview('1', 'x'), isNull);
    });
    test('cantidad o precio en cero o negativos', () {
      expect(preview('0', '10'), isNull);
      expect(preview('1', '0'), isNull);
      expect(preview('-1', '10'), isNull);
    });
    test('cantidad fraccionaria con cantidades enteras', () {
      expect(preview('0.5', '10', qty: QuantityMode.integer), isNull);
    });
    test('centavos con montos enteros', () {
      expect(preview('1', '10.50', amount: AmountMode.integer), isNull);
    });
    test('un subtotal que redondea a cero', () {
      expect(preview('0.001', '0.01'), isNull);
    });
  });
}
