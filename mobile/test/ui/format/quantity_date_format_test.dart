import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';
import 'package:pulperia_mobile/ui/format/date_format.dart';
import 'package:pulperia_mobile/ui/format/quantity_format.dart';

void main() {
  group('formatQuantity', () {
    test('una cantidad entera no lleva decimales', () {
      expect(formatQuantity(const Quantity(1000)), '1');
      expect(formatQuantity(const Quantity(12000)), '12');
    });

    test('quita los ceros finales de la parte decimal', () {
      expect(formatQuantity(const Quantity(250)), '0.25');
      expect(formatQuantity(const Quantity(1500)), '1.5');
      expect(formatQuantity(const Quantity(2125)), '2.125');
      expect(formatQuantity(const Quantity(1)), '0.001');
    });
  });

  group('formatDateTime', () {
    test('día/mes/año y hora con 24 horas, rellenando con ceros', () {
      expect(formatDateTime(DateTime(2026, 10, 2, 15, 30)), '02/10/2026 15:30');
      expect(formatDateTime(DateTime(2026, 1, 5, 7, 5)), '05/01/2026 07:05');
    });

    test('convierte de UTC a la hora local', () {
      final utc = DateTime.utc(2026, 10, 2, 15, 30);
      expect(formatDateTime(utc), formatDateTime(utc.toLocal()));
    });
  });
}
