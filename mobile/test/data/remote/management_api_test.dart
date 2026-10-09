import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulperia_mobile/data/remote/api_client.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';

import '../../support/shared_examples.dart';

const _token = 'access-token';
const _business = '0198a000-0000-7000-8000-000000000002';

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late http.Request sent;
  late http.Response Function(http.Request) respond;
  late HttpPulperiaApi api;

  setUp(() {
    api = HttpPulperiaApi(
      MockClient((request) async {
        sent = request;
        return respond(request);
      }),
      baseUrl: Uri.parse('http://10.0.2.2:5109'),
    );
  });

  Map<String, dynamic> body() => jsonDecode(sent.body) as Map<String, dynamic>;

  void expectAuthorized({bool withBusiness = true}) {
    expect(sent.headers['authorization'], 'Bearer $_token');
    expect(sent.headers['X-Business-Id'], withBusiness ? _business : isNull);
  }

  group('ajustes del negocio (RF-7 a RF-9, RF-80)', () {
    test('leer trae nombre y modos', () async {
      respond = (_) =>
          _json(exampleNamed('management.json', 'ajustes del negocio'));

      final settings = await api.getSettings(_token, _business);

      expect(sent.method, 'GET');
      expect(sent.url.path, '/api/business');
      expectAuthorized();
      expect(settings.name, 'Pulpería Ana');
      expect(settings.amountMode, AmountMode.twoDecimals);
      expect(settings.quantityMode, QuantityMode.fractional);
    });

    test('cambiar envía solo lo que cambió', () async {
      respond = (_) =>
          _json(exampleNamed('management.json', 'ajustes del negocio'));

      await api.updateSettings(_token, _business, name: 'Pulpería Ana 2');

      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/api/business');
      expect(body(), {'name': 'Pulpería Ana 2'});

      await api.updateSettings(
        _token,
        _business,
        amountMode: AmountMode.twoDecimals,
        quantityMode: QuantityMode.fractional,
      );
      expect(body(), {
        'amountMode': 'two_decimals',
        'quantityMode': 'fractional',
      });
    });

    test(
      'el rechazo por bajar de decimales a enteros sube con su código',
      () async {
        respond = (_) => _json({
          'code': 'mode_downgrade_not_allowed',
          'codes': ['mode_downgrade_not_allowed'],
        }, 400);

        await expectLater(
          api.updateSettings(_token, _business, amountMode: AmountMode.integer),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'mode_downgrade_not_allowed',
            ),
          ),
        );
      },
    );
  });

  group('equipo (RF-11, RF-70, RF-71)', () {
    test('listar trae correo y rol de cada miembro', () async {
      respond = (_) => _json([
        exampleNamed('management.json', 'miembro del equipo: dueño'),
        exampleNamed('management.json', 'miembro del equipo: empleado'),
      ]);

      final team = await api.listTeam(_token, _business);

      expect(sent.url.path, '/api/business/team');
      expectAuthorized();
      expect(team.map((m) => (m.email, m.role)), [
        ('ana@correo.com', Role.owner),
        ('beto@correo.com', Role.employee),
      ]);
    });

    test('promover y quitar usan la ruta del miembro', () async {
      respond = (_) =>
          _json(exampleNamed('management.json', 'miembro promovido'));
      await api.promote(_token, _business, 'u-4');
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/business/team/u-4/promote');
      expectAuthorized();

      respond = (_) => http.Response('', 204);
      await api.removeMember(_token, _business, 'u-4');
      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/api/business/team/u-4');
    });
  });

  group('invitaciones del dueño (RF-10, RF-69, RF-92)', () {
    test('invitar con correo y sin correo', () async {
      respond = (_) => _json(
        exampleNamed(
          'management.json',
          'invitación pendiente con correo y su código',
        ),
        201,
      );
      final withEmail = await api.invite(
        _token,
        _business,
        email: 'beto@correo.com',
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/business/invitations');
      expect(body(), {'email': 'beto@correo.com'});
      expect(withEmail.code, 'K7M2PX9Q');
      expect(withEmail.status, InvitationStatus.pending);

      respond = (_) => _json(
        exampleNamed('management.json', 'invitación pendiente solo por código'),
        201,
      );
      final codeOnly = await api.invite(_token, _business);
      expect(body(), {'email': null});
      expect(codeOnly.email, isNull);
    });

    test('listar y cancelar', () async {
      respond = (_) => _json([
        exampleNamed('management.json', 'invitación pendiente solo por código'),
      ]);
      final list = await api.listBusinessInvitations(_token, _business);
      expect(sent.url.path, '/api/business/invitations');
      expect(list.single.code, 'H4N8TW3R');

      respond = (_) => http.Response('', 204);
      await api.cancelInvitation(_token, _business, 'inv-1');
      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/api/business/invitations/inv-1');
    });
  });

  group('invitaciones recibidas (RF-67, RF-68, RF-93)', () {
    test('listar no necesita negocio', () async {
      respond = (_) =>
          _json([exampleNamed('management.json', 'invitación recibida')]);

      final offers = await api.listInvitations(_token);

      expect(sent.url.path, '/api/invitations');
      expectAuthorized(withBusiness: false);
      expect(offers.single.businessName, 'Pulpería Ana');
      expect(offers.single.email, 'beto@correo.com');
    });

    test(
      'aceptar y canjear devuelven el negocio con rol de empleado',
      () async {
        respond = (_) => _json(
          exampleNamed(
            'businesses.json',
            'negocio donde el usuario es empleado',
          ),
        );

        final accepted = await api.acceptInvitation(_token, 'inv-1');
        expect(sent.method, 'POST');
        expect(sent.url.path, '/api/invitations/inv-1/accept');
        expect(accepted.role, Role.employee);

        final redeemed = await api.redeemInvitationCode(_token, 'K7M2PX9Q');
        expect(sent.url.path, '/api/invitations/redeem');
        expect(body(), {'code': 'K7M2PX9Q'});
        expect(redeemed.name, 'Abarrotes Beto');
      },
    );

    test('rechazar', () async {
      respond = (_) => http.Response('', 204);

      await api.rejectInvitation(_token, 'inv-1');

      expect(sent.url.path, '/api/invitations/inv-1/reject');
    });
  });
}
