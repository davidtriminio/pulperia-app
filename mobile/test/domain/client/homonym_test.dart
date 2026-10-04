import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/client/homonym.dart';

import '../../support/shared_vectors.dart';

void main() {
  group('hasHomonym con los vectores compartidos (RF-17)', () {
    final cases = loadVectorCases('client-validation.json');

    test('hay al menos 25 casos', () {
      expect(cases.length, greaterThanOrEqualTo(25));
    });

    for (final c in cases) {
      test(c.name, () {
        final result = hasHomonym(
          c.input['name'] as String,
          (c.input['existingNames'] as List<dynamic>).cast<String>(),
        );

        expect(result, c.expected['duplicate']);
      });
    }
  });

  group('hasHomonym, casos adicionales', () {
    test('la eñe y su mayúscula son el mismo nombre', () {
      expect(hasHomonym('NIÑO', ['niño']), isTrue);
      expect(hasHomonym('Muñoz', ['MUÑOZ']), isTrue);
    });

    test('una lista vacía nunca tiene homónimos', () {
      expect(hasHomonym('Ana', const []), isFalse);
    });

    test('al editar un cliente, la lista no debe incluir su propio nombre', () {
      // Quien llama excluye al cliente que se edita; aquí se comprueba que
      // sin él no hay homónimo, y con él sí.
      expect(hasHomonym('Ana', ['Beto', 'Carla']), isFalse);
      expect(hasHomonym('Ana', ['Ana', 'Beto']), isTrue);
    });

    test('un nombre vacío o de espacios no tiene homónimos aunque haya vacíos en la lista', () {
      expect(hasHomonym('', ['']), isFalse);
      expect(hasHomonym('   ', ['  ', 'Ana']), isFalse);
    });

    test('no modifica la lista recibida', () {
      final existing = ['  Ana  ', 'BETO'];

      hasHomonym('ana', existing);

      expect(existing, ['  Ana  ', 'BETO']);
    });

    test('un nombre con espacios interiores distintos no es homónimo', () {
      expect(hasHomonym('Ana  María', ['Ana María']), isFalse);
    });
  });
}
