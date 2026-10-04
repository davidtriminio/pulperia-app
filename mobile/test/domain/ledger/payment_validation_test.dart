import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/ledger/payment_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

void main() {
  group('abono válido (RF-37)', () {
    test('un monto positivo se acepta y se conserva', () {
      final result = validatePayment(
        const Money(3000),
        amountMode: AmountMode.twoDecimals,
      );

      expect((result as ValidPayment).amount, const Money(3000));
    });

    test('el monto mínimo, un centavo, se acepta con 2 decimales', () {
      final result = validatePayment(
        const Money(1),
        amountMode: AmountMode.twoDecimals,
      );

      expect(result, isA<ValidPayment>());
    });

    test('un monto grande se acepta', () {
      final result = validatePayment(
        const Money(99999999000),
        amountMode: AmountMode.twoDecimals,
      );

      expect((result as ValidPayment).amount, const Money(99999999000));
    });

    test('con montos enteros, un lempira entero se acepta', () {
      final result = validatePayment(
        const Money(5000),
        amountMode: AmountMode.integer,
      );

      expect(result, isA<ValidPayment>());
    });

    test('no depende del saldo: no recibe el saldo del cliente (RF-39 deja saldo a favor)', () {
      // validatePayment solo conoce el monto y el modo de montos, así que un
      // abono mayor que la deuda nunca puede ser rechazado por validación.
      final result = validatePayment(
        const Money(12000),
        amountMode: AmountMode.twoDecimals,
      );

      expect(result, isA<ValidPayment>());
    });
  });

  group('abono rechazado (RF-38)', () {
    test('monto cero', () {
      final result = validatePayment(
        const Money(0),
        amountMode: AmountMode.twoDecimals,
      );

      expect((result as InvalidPayment).error, AmountError.notPositive);
      expect(result.error.code, 'amount_not_positive');
    });

    test('monto negativo', () {
      final result = validatePayment(
        const Money(-3000),
        amountMode: AmountMode.twoDecimals,
      );

      expect((result as InvalidPayment).error, AmountError.notPositive);
    });

    test('un centavo negativo', () {
      final result = validatePayment(
        const Money(-1),
        amountMode: AmountMode.twoDecimals,
      );

      expect((result as InvalidPayment).error, AmountError.notPositive);
    });

    test('cero y negativo se rechazan también con montos enteros', () {
      for (final minor in [0, -100, -5000]) {
        final result = validatePayment(
          Money(minor),
          amountMode: AmountMode.integer,
        );

        expect(
          (result as InvalidPayment).error,
          AmountError.notPositive,
          reason: '$minor',
        );
      }
    });
  });

  group('modo de montos del negocio (RF-36)', () {
    test('montos enteros: un abono con centavos se rechaza', () {
      for (final minor in [1250, 1, 101, 99]) {
        final result = validatePayment(
          Money(minor),
          amountMode: AmountMode.integer,
        );

        expect(
          (result as InvalidPayment).error,
          AmountError.notWhole,
          reason: '$minor',
        );
        expect(result.error.code, 'amount_not_whole');
      }
    });

    test('2 decimales: un abono con centavos se acepta', () {
      final result = validatePayment(
        const Money(1250),
        amountMode: AmountMode.twoDecimals,
      );

      expect(result, isA<ValidPayment>());
    });

    test('un monto no positivo se rechaza antes que la regla de enteros', () {
      final result = validatePayment(
        const Money(-150),
        amountMode: AmountMode.integer,
      );

      expect((result as InvalidPayment).error, AmountError.notPositive);
    });
  });
}
