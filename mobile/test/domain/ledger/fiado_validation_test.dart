import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
import 'package:pulperia_mobile/domain/ledger/fiado_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

FiadoItemDraft item({
  String description = 'Arroz',
  String? productId,
  int quantityMilli = 1000,
  int unitPrice = 2500,
}) => FiadoItemDraft(
  description: description,
  productId: productId,
  quantity: Quantity(quantityMilli),
  unitPrice: Money(unitPrice),
);

FiadoValidationResult validate(
  FiadoDraft draft, {
  AmountMode amountMode = AmountMode.twoDecimals,
  QuantityMode quantityMode = QuantityMode.fractional,
}) => validateFiado(draft, amountMode: amountMode, quantityMode: quantityMode);

List<(int?, FiadoField, String)> issuesOf(FiadoValidationResult result) => [
  for (final i in (result as InvalidFiado).issues)
    (i.itemIndex, i.field, i.code),
];

void main() {
  group('fiado con ítems (RF-28)', () {
    test(
      'cada ítem conserva descripción, producto, cantidad y precio unitario',
      () {
        final result = validate(
          FiadoWithItems([
            item(
              description: 'Arroz',
              productId: 'p-1',
              quantityMilli: 2000,
              unitPrice: 1500,
            ),
            item(
              description: 'Queso suelto',
              quantityMilli: 500,
              unitPrice: 3000,
            ),
          ]),
        );

        final valid = result as ValidFiado;
        expect(valid.items.length, 2);
        expect(valid.items[0].description, 'Arroz');
        expect(valid.items[0].productId, 'p-1');
        expect(valid.items[0].quantity, const Quantity(2000));
        expect(valid.items[0].unitPrice, const Money(1500));
        expect(valid.items[1].description, 'Queso suelto');
        expect(valid.items[1].productId, isNull);
        expect(valid.items[1].quantity, const Quantity(500));
        expect(valid.items[1].unitPrice, const Money(3000));
      },
    );

    test('el total es la suma de los subtotales de los ítems', () {
      final result = validate(
        FiadoWithItems([
          item(quantityMilli: 2000, unitPrice: 1500),
          item(quantityMilli: 500, unitPrice: 3000),
        ]),
      );

      final valid = result as ValidFiado;
      expect(valid.items[0].subtotal, const Money(3000));
      expect(valid.items[1].subtotal, const Money(1500));
      expect(valid.total, const Money(4500));
    });

    test(
      'con montos de 2 decimales el subtotal se redondea al centavo (RF-83)',
      () {
        final result = validate(
          FiadoWithItems([item(quantityMilli: 333, unitPrice: 1250)]),
        );

        final valid = result as ValidFiado;
        expect(valid.items.single.subtotal, const Money(416));
        expect(valid.total, const Money(416));
      },
    );

    test('con montos enteros el subtotal se redondea al lempira (RF-34)', () {
      final result = validate(
        FiadoWithItems([item(quantityMilli: 250, unitPrice: 3000)]),
        amountMode: AmountMode.integer,
      );

      final valid = result as ValidFiado;
      expect(valid.items.single.subtotal, const Money(800));
      expect(valid.total, const Money(800));
    });
  });

  group('fiado solo con monto total (RF-29)', () {
    test('se acepta sin ítems', () {
      final result = validate(const FiadoTotalOnly(Money(5000)));

      final valid = result as ValidFiado;
      expect(valid.total, const Money(5000));
      expect(valid.items, isEmpty);
    });
  });

  group('fiado vacío (RF-33)', () {
    test('sin ítems', () {
      expect(issuesOf(validate(const FiadoWithItems([]))), [
        (null, FiadoField.fiado, 'fiado_empty'),
      ]);
    });

    test('sin monto total', () {
      expect(issuesOf(validate(const FiadoTotalOnly(null))), [
        (null, FiadoField.fiado, 'fiado_empty'),
      ]);
    });
  });

  group('valores en cero o negativos (RF-32)', () {
    test('cantidad cero', () {
      expect(issuesOf(validate(FiadoWithItems([item(quantityMilli: 0)]))), [
        (0, FiadoField.quantity, 'quantity_not_positive'),
      ]);
    });

    test('cantidad negativa', () {
      expect(issuesOf(validate(FiadoWithItems([item(quantityMilli: -500)]))), [
        (0, FiadoField.quantity, 'quantity_not_positive'),
      ]);
    });

    test('precio unitario cero', () {
      expect(issuesOf(validate(FiadoWithItems([item(unitPrice: 0)]))), [
        (0, FiadoField.unitPrice, 'amount_not_positive'),
      ]);
    });

    test('precio unitario negativo', () {
      expect(issuesOf(validate(FiadoWithItems([item(unitPrice: -100)]))), [
        (0, FiadoField.unitPrice, 'amount_not_positive'),
      ]);
    });

    test('monto total cero', () {
      expect(issuesOf(validate(const FiadoTotalOnly(Money(0)))), [
        (null, FiadoField.total, 'amount_not_positive'),
      ]);
    });

    test('monto total negativo', () {
      expect(issuesOf(validate(const FiadoTotalOnly(Money(-5000)))), [
        (null, FiadoField.total, 'amount_not_positive'),
      ]);
    });

    test(
      'se reportan todos los problemas, ítem por ítem y campo por campo',
      () {
        final result = validate(
          FiadoWithItems([
            item(quantityMilli: 0, unitPrice: 0),
            item(),
            item(quantityMilli: -1, unitPrice: 2500),
          ]),
        );

        expect(issuesOf(result), [
          (0, FiadoField.quantity, 'quantity_not_positive'),
          (0, FiadoField.unitPrice, 'amount_not_positive'),
          (2, FiadoField.quantity, 'quantity_not_positive'),
        ]);
      },
    );

    test('un ítem cuyo subtotal redondea a cero se rechaza', () {
      final result = validate(
        FiadoWithItems([item(quantityMilli: 1, unitPrice: 100)]),
        amountMode: AmountMode.integer,
      );

      expect(issuesOf(result), [
        (0, FiadoField.subtotal, 'amount_not_positive'),
      ]);
    });
  });

  group('modos del negocio (RF-35, RF-36)', () {
    test('montos enteros: un precio con centavos se rechaza', () {
      expect(
        issuesOf(
          validate(
            FiadoWithItems([item(unitPrice: 1250)]),
            amountMode: AmountMode.integer,
          ),
        ),
        [(0, FiadoField.unitPrice, 'amount_not_whole')],
      );
    });

    test('montos enteros: un monto total con centavos se rechaza', () {
      expect(
        issuesOf(
          validate(
            const FiadoTotalOnly(Money(1250)),
            amountMode: AmountMode.integer,
          ),
        ),
        [(null, FiadoField.total, 'amount_not_whole')],
      );
    });

    test('cantidades enteras: una cantidad con fracción se rechaza', () {
      expect(
        issuesOf(
          validate(
            FiadoWithItems([item(quantityMilli: 2500)]),
            quantityMode: QuantityMode.integer,
          ),
        ),
        [(0, FiadoField.quantity, 'quantity_not_whole')],
      );
    });

    test('montos con 2 decimales y cantidades fraccionarias aceptan centavos y fracciones', () {
      final result = validate(
        FiadoWithItems([item(quantityMilli: 2500, unitPrice: 1250)]),
      );

      expect(result, isA<ValidFiado>());
    });

    test(
      'montos enteros con cantidades fraccionarias es una combinación válida',
      () {
        final result = validate(
          FiadoWithItems([item(quantityMilli: 250, unitPrice: 3000)]),
          amountMode: AmountMode.integer,
        );

        expect(result, isA<ValidFiado>());
      },
    );
  });

  group('lo que no valida', () {
    test(
      'la descripción del ítem no se valida: la spec no define regla para ella',
      () {
        final result = validate(FiadoWithItems([item(description: '')]));

        expect(result, isA<ValidFiado>());
      },
    );
  });
}
