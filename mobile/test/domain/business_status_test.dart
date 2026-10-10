import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/domain/business/business_status.dart';

void main() {
  group('estado del negocio (D-30)', () {
    test('cada estado tiene su identificador estable del servidor', () {
      expect(BusinessStatus.pending.id, 'pending');
      expect(BusinessStatus.active.id, 'active');
      expect(BusinessStatus.suspended.id, 'suspended');
      for (final status in BusinessStatus.values) {
        expect(BusinessStatus.fromId(status.id), status);
      }
    });

    test('un identificador desconocido se rechaza', () {
      expect(() => BusinessStatus.fromId('archivado'), throwsArgumentError);
    });

    test('solo un negocio activo permite registrar datos', () {
      expect(BusinessStatus.active.acceptsData, isTrue);
      expect(BusinessStatus.pending.acceptsData, isFalse);
      expect(BusinessStatus.suspended.acceptsData, isFalse);
    });
  });

  group('RemoteBusiness con estado', () {
    Map<String, dynamic> json([String? status]) => {
      'id': 'b-1',
      'name': 'Pulpería Ana',
      'role': 'owner',
      'amountMode': 'two_decimals',
      'quantityMode': 'fractional',
      'status': ?status,
    };

    test('lee el estado que manda el servidor', () {
      expect(
        RemoteBusiness.fromJson(json('pending')).status,
        BusinessStatus.pending,
      );
      expect(
        RemoteBusiness.fromJson(json('suspended')).status,
        BusinessStatus.suspended,
      );
    });

    test('sin estado (sesión guardada antes) se toma como activo', () {
      expect(RemoteBusiness.fromJson(json()).status, BusinessStatus.active);
    });

    test('el estado sobrevive a guardar y volver a leer la sesión', () {
      final business = RemoteBusiness.fromJson(json('pending'));

      expect(
        RemoteBusiness.fromJson(business.toJson()).status,
        BusinessStatus.pending,
      );
    });
  });
}
