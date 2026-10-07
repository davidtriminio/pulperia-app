import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/catalog/duplicate_product.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';

void main() {
  ProductRef ref(
    String id,
    String name, {
    SaleUnit unit = SaleUnit.unit,
    bool archived = false,
  }) => ProductRef(id: id, name: name, unit: unit, archived: archived);

  group('producto repetido por nombre y unidad (RF-91)', () {
    test('mismo nombre y misma unidad es repetido', () {
      final existing = [ref('p-1', 'Aceite', unit: SaleUnit.ounce)];

      final found = findDuplicateProduct(
        name: 'Aceite',
        unit: SaleUnit.ounce,
        existing: existing,
      );

      expect(found?.id, 'p-1');
    });

    test('ignora mayúsculas y espacios exteriores', () {
      final existing = [ref('p-1', 'Aceite Mazola')];

      expect(
        findDuplicateProduct(
          name: '  aCeItE mazola  ',
          unit: SaleUnit.unit,
          existing: existing,
        )?.id,
        'p-1',
      );
    });

    test('la eñe y su mayúscula son el mismo nombre', () {
      final existing = [ref('p-1', 'Piña')];

      expect(
        findDuplicateProduct(
          name: 'PIÑA',
          unit: SaleUnit.unit,
          existing: existing,
        )?.id,
        'p-1',
      );
    });

    test('los espacios interiores y las tildes sí cuentan', () {
      final existing = [ref('p-1', 'Aceite  vegetal'), ref('p-2', 'Azúcar')];

      expect(
        findDuplicateProduct(
          name: 'Aceite vegetal',
          unit: SaleUnit.unit,
          existing: existing,
        ),
        isNull,
      );
      expect(
        findDuplicateProduct(
          name: 'Azucar',
          unit: SaleUnit.unit,
          existing: existing,
        ),
        isNull,
      );
    });

    test('otra unidad no es repetido', () {
      final existing = [ref('p-1', 'Aceite', unit: SaleUnit.ounce)];

      expect(
        findDuplicateProduct(
          name: 'Aceite',
          unit: SaleUnit.liter,
          existing: existing,
        ),
        isNull,
      );
    });

    test('los archivados no cuentan', () {
      final existing = [
        ref('p-1', 'Aceite', unit: SaleUnit.ounce, archived: true),
      ];

      expect(
        findDuplicateProduct(
          name: 'Aceite',
          unit: SaleUnit.ounce,
          existing: existing,
        ),
        isNull,
      );
    });

    test('un archivado no tapa a un activo del mismo nombre', () {
      final existing = [
        ref('p-1', 'Aceite', archived: true),
        ref('p-2', 'Aceite'),
      ];

      expect(
        findDuplicateProduct(
          name: 'Aceite',
          unit: SaleUnit.unit,
          existing: existing,
        )?.id,
        'p-2',
      );
    });

    test('al editar, el propio producto se excluye', () {
      final existing = [ref('p-1', 'Aceite', unit: SaleUnit.ounce)];

      expect(
        findDuplicateProduct(
          name: 'Aceite',
          unit: SaleUnit.ounce,
          existing: existing,
          excludeId: 'p-1',
        ),
        isNull,
      );
    });

    test('al editar, otro producto igual sí avisa', () {
      final existing = [
        ref('p-1', 'Aceite', unit: SaleUnit.ounce),
        ref('p-2', 'Aceite Mazola', unit: SaleUnit.ounce),
      ];

      // Se renombra p-2 a "Aceite": choca con p-1.
      expect(
        findDuplicateProduct(
          name: 'Aceite',
          unit: SaleUnit.ounce,
          existing: existing,
          excludeId: 'p-2',
        )?.id,
        'p-1',
      );
    });

    test('un nombre vacío nunca es repetido', () {
      final existing = [ref('p-1', '')];

      expect(
        findDuplicateProduct(
          name: '   ',
          unit: SaleUnit.unit,
          existing: existing,
        ),
        isNull,
      );
    });

    test('sin productos no hay repetido', () {
      expect(
        findDuplicateProduct(
          name: 'Aceite',
          unit: SaleUnit.unit,
          existing: const [],
        ),
        isNull,
      );
    });

    test('con varios iguales devuelve el primero', () {
      final existing = [ref('p-1', 'Aceite'), ref('p-2', 'aceite')];

      expect(
        findDuplicateProduct(
          name: 'Aceite',
          unit: SaleUnit.unit,
          existing: existing,
        )?.id,
        'p-1',
      );
    });
  });
}
