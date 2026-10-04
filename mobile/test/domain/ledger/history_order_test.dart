import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/ledger/history_order.dart';

final class Entry implements HistoryPosition {
  const Entry(this.id, this.occurredAt, [this.serverSeq]);

  @override
  final String id;
  @override
  final DateTime occurredAt;
  @override
  final int? serverSeq;

  @override
  String toString() => id;
}

DateTime at(int minute, [int second = 0]) =>
    DateTime.utc(2026, 10, 2, 15, minute, second);

List<String> ids(Iterable<Entry> entries) => [for (final e in entries) e.id];

void main() {
  group('sortHistory (RF-41, D-18)', () {
    test('ordena por fecha de creación, del más antiguo al más reciente', () {
      final sorted = sortHistory([
        Entry('c', at(30)),
        Entry('a', at(10)),
        Entry('b', at(20)),
      ]);

      expect(ids(sorted), ['a', 'b', 'c']);
    });

    test('distingue los segundos', () {
      final sorted = sortHistory([
        Entry('b', at(5, 30)),
        Entry('a', at(5, 10)),
      ]);

      expect(ids(sorted), ['a', 'b']);
    });

    test('con la misma fecha, va primero el que llegó antes al servidor', () {
      final sorted = sortHistory([
        Entry('late', at(10), 8),
        Entry('early', at(10), 3),
      ]);

      expect(ids(sorted), ['early', 'late']);
    });

    test(
      'con la misma fecha, lo ya sincronizado va antes que lo pendiente',
      () {
        final sorted = sortHistory([
          Entry('pending', at(10)),
          Entry('synced', at(10), 99),
        ]);

        expect(ids(sorted), ['synced', 'pending']);
      },
    );

    test('con la misma fecha y sin orden de servidor, desempata por id', () {
      final sorted = sortHistory([
        Entry('b', at(10)),
        Entry('c', at(10)),
        Entry('a', at(10)),
      ]);

      expect(ids(sorted), ['a', 'b', 'c']);
    });

    test(
      'con la misma fecha y el mismo orden de servidor, desempata por id',
      () {
        final sorted = sortHistory([
          Entry('b', at(10), 5),
          Entry('a', at(10), 5),
        ]);

        expect(ids(sorted), ['a', 'b']);
      },
    );

    test('el orden de servidor nunca pasa por encima de la fecha', () {
      // El primero se creó antes pero llegó al servidor después.
      final sorted = sortHistory([
        Entry('created-later', at(20), 1),
        Entry('created-earlier', at(10), 50),
      ]);

      expect(ids(sorted), ['created-earlier', 'created-later']);
    });

    test(
      'la misma fecha expresada en hora local o en UTC cuenta como igual',
      () {
        final utc = DateTime.utc(2026, 10, 2, 15, 10);
        final local = utc.toLocal();

        final sorted = sortHistory([Entry('b', local, 2), Entry('a', utc, 1)]);

        expect(ids(sorted), ['a', 'b']);
      },
    );

    test('el resultado no depende del orden de entrada', () {
      final entries = [
        Entry('a', at(10), 1),
        Entry('b', at(10), 2),
        Entry('c', at(10)),
        Entry('d', at(10)),
        Entry('e', at(5), 9),
        Entry('f', at(20)),
        Entry('g', at(20), 4),
        Entry('h', at(5)),
      ];
      final expected = ids(sortHistory(entries));
      final random = Random(11);

      for (var i = 0; i < 100; i++) {
        final shuffled = [...entries]..shuffle(random);

        expect(ids(sortHistory(shuffled)), expected);
      }
    });

    test('no modifica la colección recibida', () {
      final original = [Entry('b', at(20)), Entry('a', at(10))];

      sortHistory(original);

      expect(ids(original), ['b', 'a']);
    });

    test('una colección vacía da una lista vacía', () {
      expect(sortHistory<Entry>(const []), isEmpty);
    });
  });
}
