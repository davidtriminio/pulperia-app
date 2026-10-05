import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/ids.dart';

void main() {
  final format = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('devuelve un UUID en minúsculas', () {
    final id = newId();
    expect(id, id.toLowerCase());
    expect(id, hasLength(36));
  });

  test('es un UUID v7 con la variante RFC 9562', () {
    for (var i = 0; i < 1000; i++) {
      final id = newId();
      expect(id, matches(format), reason: id);
      expect(id[14], '7');
      expect('89ab', contains(id[19]));
    }
  });

  test('100 000 ids no se repiten', () {
    final ids = {for (var i = 0; i < 100000; i++) newId()};
    expect(ids, hasLength(100000));
  });

  test('crecen con el tiempo, sin desorden dentro de una ráfaga', () {
    var previous = newId();
    for (var i = 0; i < 100000; i++) {
      final next = newId();
      expect(
        next.compareTo(previous),
        greaterThan(0),
        reason: '$previous $next',
      );
      previous = next;
    }
  });

  test('ids generados con tiempo posterior ordenan después', () async {
    final first = newId();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(newId().compareTo(first), greaterThan(0));
  });
}
