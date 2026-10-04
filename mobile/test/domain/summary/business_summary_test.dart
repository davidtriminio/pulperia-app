import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/summary/business_summary.dart';

import '../../support/shared_vectors.dart';

ClientBalance clientBalance(String id, int balance, {bool archived = false}) =>
    ClientBalance(id: id, balance: Balance(Money(balance)), archived: archived);

List<ClientBalance> clientsOf(Map<String, dynamic> input) => [
  for (final c in input['clients'] as List<dynamic>)
    clientBalance(
      (c as Map<String, dynamic>)['id'] as String,
      c['balance'] as int,
      archived: c['archived'] as bool,
    ),
];

void main() {
  group('summarize con los vectores compartidos (RF-63, RF-64, RF-65)', () {
    final cases = loadVectorCases('summary.json');

    test('hay al menos 15 casos', () {
      expect(cases.length, greaterThanOrEqualTo(15));
    });

    for (final c in cases) {
      test(c.name, () {
        final summary = summarize(clientsOf(c.input));

        expect(summary.debtTotal.minorUnits, c.expected['debtTotal']);
        expect(summary.creditTotal.minorUnits, c.expected['creditTotal']);
        expect([
          for (final d in summary.debtors) d.clientId,
        ], c.expected['topDebtorIds']);
      });
    }
  });

  group('summarize, propiedades', () {
    final clients = [
      clientBalance('c-01', 12000),
      clientBalance('c-02', -3000),
      clientBalance('c-03', 0),
      clientBalance('c-04', 8000),
      clientBalance('c-05', 50000, archived: true),
      clientBalance('c-06', -700, archived: true),
      clientBalance('c-07', 8000),
      clientBalance('c-08', -250),
      clientBalance('c-09', 1),
    ];

    test('el orden de entrada de los clientes no altera el resumen', () {
      final expected = summarize(clients);
      final random = Random(7);

      for (var i = 0; i < 50; i++) {
        final shuffled = [...clients]..shuffle(random);
        final summary = summarize(shuffled);

        expect(summary.debtTotal, expected.debtTotal);
        expect(summary.creditTotal, expected.creditTotal);
        expect(
          [for (final d in summary.debtors) d.clientId],
          [for (final d in expected.debtors) d.clientId],
        );
      }
    });

    test('la deuda total es la suma de la deuda de la lista', () {
      final summary = summarize(clients);

      final sum = summary.debtors.fold(
        Money.zero,
        (total, d) => total + d.debt,
      );
      expect(sum, summary.debtTotal);
    });

    test(
      'la lista va de mayor a menor deuda y desempata por id ascendente',
      () {
        final debtors = summarize(clients).debtors;

        for (var i = 1; i < debtors.length; i++) {
          final previous = debtors[i - 1];
          final current = debtors[i];
          final byDebt = previous.debt.compareTo(current.debt);

          expect(byDebt >= 0, isTrue);
          if (byDebt == 0) {
            expect(previous.clientId.compareTo(current.clientId) < 0, isTrue);
          }
        }
      },
    );

    test('los archivados no aparecen en la lista ni suman', () {
      final summary = summarize(clients);

      expect(summary.debtors.map((d) => d.clientId), isNot(contains('c-05')));
      expect(summary.creditTotal, const Money(3250));
    });

    test('los saldados no aparecen en la lista', () {
      expect(
        summarize(clients).debtors.map((d) => d.clientId),
        isNot(contains('c-03')),
      );
    });

    test('el saldo a favor no resta de la deuda total (RF-64)', () {
      final summary = summarize([
        clientBalance('a', 5000),
        clientBalance('b', -2000),
      ]);

      expect(summary.debtTotal, const Money(5000));
      expect(summary.creditTotal, const Money(2000));
    });

    test('un negocio sin clientes tiene un resumen vacío', () {
      final summary = summarize(const []);

      expect(summary.debtTotal, Money.zero);
      expect(summary.creditTotal, Money.zero);
      expect(summary.debtors, isEmpty);
    });
  });
}
