import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/catalog/price_change.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/shared_vectors.dart';

PriceHistory _history(Object? previous, Object? changedAt) => PriceHistory(
  previousPrice: previous == null ? null : Money(previous as int),
  changedAt: changedAt == null ? null : DateTime.parse(changedAt as String),
);

void main() {
  group('precio anterior con los vectores compartidos (RF-90)', () {
    final cases = loadVectorCases('price-change.json');

    test('hay al menos 12 casos', () {
      expect(cases.length, greaterThanOrEqualTo(12));
    });

    for (final c in cases) {
      test(c.name, () {
        final result = applyPriceChange(
          currentPrice: Money(c.input['current_price'] as int),
          current: _history(
            c.input['previous_price'],
            c.input['price_changed_at'],
          ),
          newPrice: Money(c.input['new_price'] as int),
          at: DateTime.parse(c.input['at'] as String),
        );

        final expected = _history(
          c.expected['previous_price'],
          c.expected['price_changed_at'],
        );
        expect(result.previousPrice, expected.previousPrice);
        expect(result.changedAt, expected.changedAt);
        expect(result.changedAt?.isUtc ?? true, isTrue);
      });
    }
  });

  group('precio anterior, casos adicionales', () {
    test('dos cambios en cadena dejan siempre el último anterior', () {
      var history = const PriceHistory();
      var price = Money(2000);
      for (final next in [2500, 2000, 3000]) {
        history = applyPriceChange(
          currentPrice: price,
          current: history,
          newPrice: Money(next),
          at: DateTime.utc(2026, 10, 5, next),
        );
        price = Money(next);
      }

      expect(history.previousPrice, Money(2000));
    });

    test('la fecha se guarda en UTC aunque llegue con otra zona', () {
      final result = applyPriceChange(
        currentPrice: Money(100),
        current: const PriceHistory(),
        newPrice: Money(200),
        at: DateTime.parse('2026-10-05T08:30:00-06:00'),
      );

      expect(result.changedAt, DateTime.utc(2026, 10, 5, 14, 30));
      expect(result.changedAt!.isUtc, isTrue);
    });
  });
}
