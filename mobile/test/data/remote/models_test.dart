import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';

import '../../support/shared_examples.dart';

void main() {
  group('modelos del contrato, leídos de shared/examples', () {
    test('tokens: fechas en UTC', () {
      final tokens = ApiTokens.fromJson(exampleNamed('auth.json', 'inicio'));

      expect(tokens.userId, '0198a000-0000-7000-8000-000000000001');
      expect(tokens.accessToken, startsWith('k3J2'));
      expect(tokens.accessExpiresAt, DateTime.utc(2026, 10, 9, 15, 15));
      expect(tokens.accessExpiresAt.isUtc, isTrue);
      expect(tokens.refreshExpiresAt, DateTime.utc(2027, 1, 7, 15));
    });

    test('registro: usuario y negocio', () {
      final registered = RegisteredAccount.fromJson(
        exampleNamed('auth.json', 'registro'),
      );

      expect(registered.userId, '0198a000-0000-7000-8000-000000000001');
      expect(registered.businessId, '0198a000-0000-7000-8000-000000000002');
    });

    test('negocios: rol y modos como enums del dominio', () {
      final owner = RemoteBusiness.fromJson(
        exampleNamed('businesses.json', 'negocio donde el usuario es dueño'),
      );
      final employee = RemoteBusiness.fromJson(
        exampleNamed('businesses.json', 'negocio donde el usuario es empleado'),
      );

      expect(
        (owner.name, owner.role, owner.amountMode, owner.quantityMode),
        (
          'Pulpería Ana',
          Role.owner,
          AmountMode.twoDecimals,
          QuantityMode.fractional,
        ),
      );
      expect(
        (employee.role, employee.amountMode, employee.quantityMode),
        (Role.employee, AmountMode.integer, QuantityMode.integer),
      );
    });

    test('resultado de una operación: aplicada, repetida y rechazada', () {
      final applied = OperationResult.fromJson(
        exampleNamed('sync.json', 'operación aplicada'),
      );
      final duplicate = OperationResult.fromJson(
        exampleNamed('sync.json', 'operación repetida'),
      );
      final rejected = OperationResult.fromJson(
        exampleNamed('sync.json', 'operación rechazada con su código'),
      );
      final several = OperationResult.fromJson(
        exampleNamed('sync.json', 'operación rechazada por varios'),
      );

      expect(applied.status, OperationStatus.applied);
      expect(applied.code, isNull);
      expect(applied.codes, isEmpty);
      expect(duplicate.status, OperationStatus.duplicate);
      expect(rejected.status, OperationStatus.rejected);
      expect(rejected.code, 'version_conflict');
      expect(several.codes, ['amount_too_large', 'quantity_too_large']);
    });

    test('página de cambios con los cuatro tipos de registro', () {
      final page = PullPage.fromJson(
        exampleNamed('sync.json', 'página con un cliente'),
      );

      expect((page.cursor, page.hasMore, page.changes.length), (12, true, 4));
      final [client, product, fiado, payment] = page.changes;

      expect(client.seq, 8);
      expect(client.entity, isA<RemoteClient>());
      final c = client.entity as RemoteClient;
      expect(
        (c.name, c.phone, c.address, c.version, c.archived),
        ('Ana López', '98765432', null, 2, false),
      );
      expect(c.updatedAt, DateTime.utc(2026, 10, 9, 14, 30));

      final p = product.entity as RemoteProduct;
      expect(
        (p.price, p.unit, p.previousPrice, p.priceChangedAt),
        (2800, SaleUnit.pound, 2500, DateTime.utc(2026, 10, 9, 14, 10)),
      );

      final f = fiado.entity as RemoteFiado;
      expect(
        (fiado.seq, f.total, f.serverSeq, f.annulledBy != null),
        (11, 1400, 10, true),
      );
      expect(f.items.single.quantity, 500);
      expect(f.items.single.unit, SaleUnit.pound);
      expect(f.items.single.productId, '0198a000-0000-7000-8000-0000000000d1');

      final pay = payment.entity as RemotePayment;
      expect((pay.amount, pay.serverSeq), (500, 12));
      expect(pay.annulledAt, isNull);
    });

    test('página vacía: el cursor se conserva', () {
      final page = PullPage.fromJson(
        exampleNamed('sync.json', 'página de cambios vacía'),
      );

      expect((page.cursor, page.hasMore), (7, false));
      expect(page.changes, isEmpty);
    });

    test('error: código principal y todos los códigos', () {
      final one = ApiError.fromJson(exampleNamed('errors.json', 'un solo'));
      final many = ApiError.fromJson(exampleNamed('errors.json', 'varios'));

      expect(one.code, 'invalid_credentials');
      expect(one.codes, ['invalid_credentials']);
      expect(many.codes, ['email_invalid', 'password_too_short']);
    });
  });

  group('lo que el móvil envía', () {
    test('una operación del lote tiene la forma del contrato', () {
      final json = PushOperation(
        opId: 'op-1',
        type: 'client.update',
        entityId: 'c-1',
        payload: {'name': 'Ana'},
        baseVersion: 3,
        createdAt: DateTime.utc(2026, 10, 9, 14),
      ).toJson();

      expect(json, {
        'opId': 'op-1',
        'type': 'client.update',
        'entityId': 'c-1',
        'payload': {'name': 'Ana'},
        'baseVersion': 3,
        'createdAt': '2026-10-09T14:00:00.000Z',
      });
    });

    test('sin versión base se envía null', () {
      final json = PushOperation(
        opId: 'op-1',
        type: 'client.create',
        entityId: 'c-1',
        payload: const {},
        createdAt: DateTime.utc(2026, 10, 9),
      ).toJson();

      expect(json['baseVersion'], isNull);
    });
  });
}
