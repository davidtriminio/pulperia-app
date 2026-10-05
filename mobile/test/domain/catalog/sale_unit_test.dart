import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

void main() {
  final shared = jsonDecode(
    File('../shared/vectors/units.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final sharedUnits = [
    for (final u in shared['units'] as List<dynamic>) u as Map<String, dynamic>,
  ];

  group('la lista del móvil coincide con la compartida en shared/ (RF-86)', () {
    test('tiene exactamente las 10 unidades, en el mismo orden', () {
      expect(SaleUnit.values.map((u) => u.id), [
        for (final u in sharedUnits) u['id'],
      ]);
      expect(SaleUnit.values, hasLength(10));
    });

    test('nombre, plural y abreviatura de cada una', () {
      for (final expected in sharedUnits) {
        final unit = SaleUnit.fromId(expected['id'] as String);
        expect(unit.singular, expected['singular'], reason: unit.id);
        expect(unit.plural, expected['plural'], reason: unit.id);
        expect(unit.abbreviation, expected['abbreviation'], reason: unit.id);
      }
    });

    test('la unidad por omisión es la compartida', () {
      expect(SaleUnit.defaultUnit.id, shared['default']);
      expect(SaleUnit.defaultUnit, SaleUnit.unit);
    });

    test('los ids son únicos', () {
      final ids = SaleUnit.values.map((u) => u.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('fromId y tryFromId', () {
    test('lee cada unidad por su id', () {
      expect(SaleUnit.fromId('pound'), SaleUnit.pound);
      expect(SaleUnit.fromId('dozen'), SaleUnit.dozen);
    });

    test('un id fuera de la lista se rechaza', () {
      expect(() => SaleUnit.fromId('stone'), throwsArgumentError);
      expect(() => SaleUnit.fromId(''), throwsArgumentError);
      expect(() => SaleUnit.fromId('POUND'), throwsArgumentError);
    });

    test('tryFromId devuelve null si no existe', () {
      expect(SaleUnit.tryFromId('stone'), isNull);
      expect(SaleUnit.tryFromId(null), isNull);
      expect(SaleUnit.tryFromId('kilo'), SaleUnit.kilo);
    });

    test('isValidId dice si el id está en la lista', () {
      expect(SaleUnit.isValidId('bag'), isTrue);
      expect(SaleUnit.isValidId('bags'), isFalse);
      expect(SaleUnit.isValidId(null), isFalse);
    });
  });

  group('nameFor: singular solo con cantidad exactamente 1', () {
    test('una libra', () {
      expect(SaleUnit.pound.nameFor(const Quantity(1000)), 'libra');
    });
    test('varias libras', () {
      expect(SaleUnit.pound.nameFor(const Quantity(2000)), 'libras');
      expect(SaleUnit.pound.nameFor(const Quantity(2500)), 'libras');
    });
    test('menos de una también va en plural', () {
      expect(SaleUnit.pound.nameFor(const Quantity(500)), 'libras');
      expect(SaleUnit.dozen.nameFor(const Quantity(1)), 'docenas');
    });
    test('plurales irregulares', () {
      expect(SaleUnit.gallon.nameFor(const Quantity(1000)), 'galón');
      expect(SaleUnit.gallon.nameFor(const Quantity(3000)), 'galones');
      expect(SaleUnit.unit.nameFor(const Quantity(1000)), 'unidad');
      expect(SaleUnit.unit.nameFor(const Quantity(12000)), 'unidades');
    });
  });
}
