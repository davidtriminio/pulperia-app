import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/catalog/product_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

List<(ProductField, String)> issuesOf(ProductValidationResult result) =>
    switch (result) {
      ValidProduct() => const [],
      InvalidProduct(:final issues) => [
        for (final i in issues) (i.field, i.code),
      ],
    };

ProductValidationResult validate(
  String name,
  int price, {
  AmountMode mode = AmountMode.twoDecimals,
}) => validateProduct(name: name, price: Money(price), amountMode: mode);

void main() {
  group('producto válido (RF-24)', () {
    test('con nombre y precio positivo', () {
      expect(issuesOf(validate('Arroz', 2500)), isEmpty);
    });

    test('el precio mínimo, un centavo, con 2 decimales', () {
      expect(issuesOf(validate('Fósforo', 1)), isEmpty);
    });

    test('con montos enteros, un precio en lempiras enteros', () {
      expect(
        issuesOf(validate('Arroz', 2500, mode: AmountMode.integer)),
        isEmpty,
      );
    });

    test('devuelve el nombre y el precio sin cambiar el precio', () {
      final result = validate('Arroz', 2500) as ValidProduct;

      expect(result.name, 'Arroz');
      expect(result.price, const Money(2500));
    });

    test('el nombre se devuelve sin espacios exteriores', () {
      expect((validate('  Arroz \t', 2500) as ValidProduct).name, 'Arroz');
    });
  });

  group('nombre obligatorio', () {
    test('vacío', () {
      expect(issuesOf(validate('', 2500)), [
        (ProductField.name, 'product_name_required'),
      ]);
    });

    test('solo espacios', () {
      expect(issuesOf(validate('   ', 2500)), [
        (ProductField.name, 'product_name_required'),
      ]);
    });
  });

  group('precio', () {
    test('cero se rechaza', () {
      expect(issuesOf(validate('Arroz', 0)), [
        (ProductField.price, 'amount_not_positive'),
      ]);
    });

    test('negativo se rechaza', () {
      expect(issuesOf(validate('Arroz', -100)), [
        (ProductField.price, 'amount_not_positive'),
      ]);
    });

    test('con montos enteros, un precio con centavos se rechaza (RF-36)', () {
      expect(issuesOf(validate('Arroz', 1250, mode: AmountMode.integer)), [
        (ProductField.price, 'amount_not_whole'),
      ]);
    });

    test('con 2 decimales, un precio con centavos se acepta', () {
      expect(issuesOf(validate('Arroz', 1250)), isEmpty);
    });
  });

  group('varios problemas a la vez', () {
    test('nombre primero, precio después', () {
      expect(issuesOf(validate('', 0)), [
        (ProductField.name, 'product_name_required'),
        (ProductField.price, 'amount_not_positive'),
      ]);
    });
  });
}
