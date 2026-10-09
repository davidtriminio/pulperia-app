import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulperia_mobile/data/remote/api_client.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';

import '../../support/shared_examples.dart';

/// Lo que el cliente envió, para comprobarlo.
class _Sent {
  late http.Request request;

  Map<String, dynamic> get json =>
      jsonDecode(request.body) as Map<String, dynamic>;
}

final _base = Uri.parse('http://10.0.2.2:5109');
const _token = 'access-token';
const _business = '0198a000-0000-7000-8000-000000000002';

HttpPulperiaApi _api(
  _Sent sent,
  http.Response Function(http.Request) respond, {
  Duration timeout = const Duration(seconds: 5),
}) => HttpPulperiaApi(
  MockClient((request) async {
    sent.request = request;
    return respond(request);
  }),
  baseUrl: _base,
  timeout: timeout,
);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('cuentas', () {
    test(
      'registrar envía los datos del contrato y devuelve la cuenta',
      () async {
        final sent = _Sent();
        final api = _api(
          sent,
          (_) => _json(exampleNamed('auth.json', 'registro'), 201),
        );

        final registered = await api.register(
          email: 'ana@correo.com',
          password: 'contrasena1',
          businessName: 'Pulpería Ana',
          amountMode: AmountMode.twoDecimals,
          quantityMode: QuantityMode.fractional,
        );

        expect(sent.request.method, 'POST');
        expect(
          sent.request.url,
          Uri.parse('http://10.0.2.2:5109/api/auth/register'),
        );
        expect(
          sent.request.headers['content-type'],
          contains('application/json'),
        );
        expect(sent.json, {
          'email': 'ana@correo.com',
          'password': 'contrasena1',
          'businessName': 'Pulpería Ana',
          'amountMode': 'two_decimals',
          'quantityMode': 'fractional',
        });
        expect(registered.businessId, '0198a000-0000-7000-8000-000000000002');
      },
    );

    test('iniciar sesión devuelve los tokens y no manda token', () async {
      final sent = _Sent();
      final api = _api(sent, (_) => _json(exampleNamed('auth.json', 'inicio')));

      final tokens = await api.login('ana@correo.com', 'contrasena1');

      expect(sent.request.url.path, '/api/auth/login');
      expect(sent.request.headers.containsKey('authorization'), isFalse);
      expect(sent.json, {'email': 'ana@correo.com', 'password': 'contrasena1'});
      expect(tokens.refreshToken, startsWith('Yh6T'));
    });

    test('renovar manda el token de renovación', () async {
      final sent = _Sent();
      final api = _api(sent, (_) => _json(exampleNamed('auth.json', 'inicio')));

      await api.refresh('el-de-renovacion');

      expect(sent.request.url.path, '/api/auth/refresh');
      expect(sent.json, {'refreshToken': 'el-de-renovacion'});
    });

    test('cerrar sesión manda el token de acceso y acepta el 204', () async {
      final sent = _Sent();
      final api = _api(sent, (_) => http.Response('', 204));

      await api.logout(_token);

      expect(sent.request.url.path, '/api/auth/logout');
      expect(sent.request.headers['authorization'], 'Bearer $_token');
    });
  });

  group('negocios', () {
    test('listar usa el token y devuelve negocios con su rol', () async {
      final sent = _Sent();
      final api = _api(
        sent,
        (_) => _json([
          exampleNamed('businesses.json', 'negocio donde el usuario es dueño'),
          exampleNamed(
            'businesses.json',
            'negocio donde el usuario es empleado',
          ),
        ]),
      );

      final list = await api.listBusinesses(_token);

      expect(sent.request.method, 'GET');
      expect(sent.request.url.path, '/api/businesses');
      expect(sent.request.headers['authorization'], 'Bearer $_token');
      expect(list.map((b) => b.name), ['Pulpería Ana', 'Abarrotes Beto']);
    });

    test('crear envía nombre y modos', () async {
      final sent = _Sent();
      final api = _api(
        sent,
        (_) => _json(
          exampleNamed('businesses.json', 'negocio donde el usuario es dueño'),
          201,
        ),
      );

      final business = await api.createBusiness(
        _token,
        name: 'Segunda sucursal',
        amountMode: AmountMode.integer,
        quantityMode: QuantityMode.integer,
      );

      expect(sent.request.method, 'POST');
      expect(sent.json, {
        'name': 'Segunda sucursal',
        'amountMode': 'integer',
        'quantityMode': 'integer',
      });
      expect(business.name, 'Pulpería Ana');
    });
  });

  group('sincronización', () {
    test('enviar un lote lleva token, negocio y las operaciones', () async {
      final sent = _Sent();
      final api = _api(
        sent,
        (_) => _json(exampleNamed('sync.json', 'lote con una aplicada')),
      );

      final results = await api.push(_token, _business, [
        PushOperation(
          opId: 'op-1',
          type: 'client.create',
          entityId: 'c-1',
          payload: {'name': 'Ana'},
          createdAt: DateTime.utc(2026, 10, 9, 14),
        ),
      ]);

      expect(sent.request.method, 'POST');
      expect(sent.request.url.path, '/api/sync/push');
      expect(sent.request.headers['authorization'], 'Bearer $_token');
      expect(sent.request.headers['x-business-id'], _business);
      expect(
        (sent.json['operations'] as List).single,
        containsPair('opId', 'op-1'),
      );
      expect(results.map((r) => r.status), [
        OperationStatus.applied,
        OperationStatus.duplicate,
        OperationStatus.rejected,
      ]);
      expect(results.last.code, 'client_not_found');
    });

    test('pedir cambios lleva cursor y límite en la consulta', () async {
      final sent = _Sent();
      final api = _api(
        sent,
        (_) => _json(exampleNamed('sync.json', 'página de cambios vacía')),
      );

      final page = await api.pull(_token, _business, cursor: 41, limit: 100);

      expect(sent.request.method, 'GET');
      expect(sent.request.url.path, '/api/sync/pull');
      expect(sent.request.url.queryParameters, {
        'cursor': '41',
        'limit': '100',
      });
      expect(sent.request.headers['x-business-id'], _business);
      expect(page.cursor, 7);
    });

    test('pedir cambios sin límite no lo manda', () async {
      final sent = _Sent();
      final api = _api(
        sent,
        (_) => _json(exampleNamed('sync.json', 'página de cambios vacía')),
      );

      await api.pull(_token, _business, cursor: 0);

      expect(sent.request.url.queryParameters, {'cursor': '0'});
    });
  });

  group('errores', () {
    test('un error de la API conserva el estado y el código estable', () async {
      final api = _api(
        _Sent(),
        (_) => _json(exampleNamed('errors.json', 'un solo'), 401),
      );

      await expectLater(
        api.login('ana@correo.com', 'mala'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 401)
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having((e) => e.codes, 'codes', ['invalid_credentials']),
        ),
      );
    });

    test('un error con varios códigos los conserva todos', () async {
      final api = _api(
        _Sent(),
        (_) => _json(exampleNamed('errors.json', 'varios'), 400),
      );

      await expectLater(
        api.register(
          email: 'x',
          password: 'y',
          businessName: 'z',
          amountMode: AmountMode.integer,
          quantityMode: QuantityMode.integer,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.codes, 'codes', [
            'email_invalid',
            'password_too_short',
          ]),
        ),
      );
    });

    test(
      'un error sin el cuerpo del contrato no rompe: código genérico',
      () async {
        final api = _api(
          _Sent(),
          (_) => http.Response('<html>502</html>', 502),
        );

        await expectLater(
          api.listBusinesses(_token),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 502)
                .having((e) => e.code, 'code', ApiException.unexpectedResponse),
          ),
        );
      },
    );

    test(
      'un éxito que no cumple el contrato es una respuesta inválida',
      () async {
        final api = _api(_Sent(), (_) => _json({'cursor': 'no-es-numero'}));

        await expectLater(
          api.pull(_token, _business, cursor: 0),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ApiException.invalidResponse,
            ),
          ),
        );
      },
    );

    test(
      'sin red (socket, cliente HTTP o tiempo agotado) es NetworkException',
      () async {
        for (final failure in <Object>[
          const SocketException('sin ruta'),
          http.ClientException('sin conexión'),
          TimeoutException('lento'),
        ]) {
          final api = HttpPulperiaApi(
            MockClient((_) async => throw failure),
            baseUrl: _base,
          );

          await expectLater(
            api.login('a@b.c', 'x'),
            throwsA(isA<NetworkException>()),
            reason: '$failure',
          );
        }
      },
    );

    test('un servidor que no responde a tiempo es NetworkException', () async {
      final api = HttpPulperiaApi(
        MockClient((_) => Completer<http.Response>().future),
        baseUrl: _base,
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        api.listBusinesses(_token),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
