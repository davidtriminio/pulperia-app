import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/shared_vectors.dart';

List<LedgerMovement> movementsOf(Map<String, dynamic> input) => [
  for (final m in input['movements'] as List<dynamic>)
    LedgerMovement(
      kind: (m as Map<String, dynamic>)['type'] == 'fiado'
          ? MovementKind.fiado
          : MovementKind.payment,
      amount: Money(m['amount'] as int),
      annulled: m['annulled'] as bool,
    ),
];

LedgerMovement fiado(int amount, {bool annulled = false}) => LedgerMovement(
  kind: MovementKind.fiado,
  amount: Money(amount),
  annulled: annulled,
);

LedgerMovement payment(int amount, {bool annulled = false}) => LedgerMovement(
  kind: MovementKind.payment,
  amount: Money(amount),
  annulled: annulled,
);

void main() {
  group(
    'computeBalance con los vectores compartidos (RF-39, 40, 42, 44, 47)',
    () {
      final cases = loadVectorCases('balance.json');

      test('hay al menos 15 casos', () {
        expect(cases.length, greaterThanOrEqualTo(15));
      });

      for (final c in cases) {
        test(c.name, () {
          final balance = computeBalance(movementsOf(c.input));

          expect(balance.amount.minorUnits, c.expected['balance']);
          expect(balance.label.id, c.expected['label']);
        });
      }
    },
  );

  group('computeBalance, propiedades', () {
    test('el orden de los movimientos no altera el saldo', () {
      final movements = [
        fiado(1500),
        fiado(2500),
        payment(1000),
        fiado(4000, annulled: true),
        payment(700),
        fiado(999),
        payment(300, annulled: true),
      ];
      final expected = computeBalance(movements);
      final random = Random(42);

      for (var i = 0; i < 50; i++) {
        final shuffled = [...movements]..shuffle(random);

        expect(computeBalance(shuffled).amount, expected.amount);
        expect(computeBalance(shuffled).label, expected.label);
      }
    });

    test('añadir un movimiento anulado nunca cambia el saldo', () {
      final base = [fiado(5000), payment(2000)];
      final expected = computeBalance(base);

      expect(
        computeBalance([...base, fiado(123456, annulled: true)]).amount,
        expected.amount,
      );
      expect(
        computeBalance([...base, payment(98765, annulled: true)]).amount,
        expected.amount,
      );
    });

    test('anular un movimiento es lo mismo que quitarlo', () {
      final withAnnulled = [
        fiado(5000),
        fiado(3000, annulled: true),
        payment(1000),
      ];
      final without = [fiado(5000), payment(1000)];

      expect(
        computeBalance(withAnnulled).amount,
        computeBalance(without).amount,
      );
    });

    test(
      'un fiado sube el saldo y un abono lo baja, exactamente por su monto',
      () {
        final base = [fiado(10000)];
        final before = computeBalance(base).amount;

        expect(
          computeBalance([...base, fiado(750)]).amount,
          before + const Money(750),
        );
        expect(
          computeBalance([...base, payment(750)]).amount,
          before - const Money(750),
        );
      },
    );

    test('la etiqueta siempre coincide con el signo del saldo', () {
      for (final amount in [-5000, -1, 0, 1, 5000]) {
        final balance = Balance(Money(amount));

        expect(
          balance.label,
          amount > 0
              ? BalanceLabel.debt
              : amount < 0
              ? BalanceLabel.credit
              : BalanceLabel.settled,
        );
      }
    });

    test('una lista vacía da saldo cero y saldado', () {
      final balance = computeBalance(const []);

      expect(balance.amount, Money.zero);
      expect(balance.label, BalanceLabel.settled);
    });
  });

  group('Balance', () {
    test(
      'la deuda y el saldo a favor se expresan siempre como montos positivos',
      () {
        expect(const Balance(Money(7000)).debt, const Money(7000));
        expect(const Balance(Money(7000)).credit, Money.zero);
        expect(const Balance(Money(-2000)).debt, Money.zero);
        expect(const Balance(Money(-2000)).credit, const Money(2000));
        expect(const Balance(Money.zero).debt, Money.zero);
        expect(const Balance(Money.zero).credit, Money.zero);
      },
    );

    test('igualdad por valor', () {
      expect(const Balance(Money(100)), const Balance(Money(100)));
      expect(
        const Balance(Money(100)).hashCode,
        const Balance(Money(100)).hashCode,
      );
      expect(const Balance(Money(100)), isNot(const Balance(Money(-100))));
    });
  });
}
