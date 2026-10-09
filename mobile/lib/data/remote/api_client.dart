import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import 'models.dart';

/// Lo que la app sabe pedirle al servidor (D-17). Es una interfaz para que las
/// pruebas la sustituyan por una falsa: nada fuera de `data/remote` conoce HTTP.
///
/// Los errores son [ApiException] (el servidor respondió) o [NetworkException]
/// (no se pudo hablar con él).
abstract interface class PulperiaApi {
  Future<RegisteredAccount> register({
    required String email,
    required String password,
    required String businessName,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  });

  Future<ApiTokens> login(String email, String password);

  Future<ApiTokens> refresh(String refreshToken);

  Future<void> logout(String accessToken);

  Future<List<RemoteBusiness>> listBusinesses(String accessToken);

  Future<RemoteBusiness> createBusiness(
    String accessToken, {
    required String name,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  });

  /// Envía un lote de operaciones (RF-52): un resultado por operación, en el
  /// mismo orden.
  Future<List<OperationResult>> push(
    String accessToken,
    String businessId,
    List<PushOperation> operations,
  );

  /// Pide los cambios posteriores a [cursor]; con cursor cero es la descarga
  /// inicial (RF-58).
  Future<PullPage> pull(
    String accessToken,
    String businessId, {
    required int cursor,
    int? limit,
  });
}

/// El cliente HTTP escrito a mano contra `shared/openapi.json` (D-17, D-31).
final class HttpPulperiaApi implements PulperiaApi {
  HttpPulperiaApi(
    this._client, {
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
  });

  final http.Client _client;

  /// Dirección del servidor, sin ruta (por ejemplo `http://10.0.2.2:5109`).
  final Uri baseUrl;

  /// Cuánto se espera una respuesta antes de darla por perdida.
  final Duration timeout;

  static const _businessHeader = 'X-Business-Id';

  Uri _uri(String path, [Map<String, String>? query]) => baseUrl.replace(
    path: path,
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  Map<String, String> _headers({String? accessToken, String? businessId}) => {
    'accept': 'application/json',
    if (accessToken != null) 'authorization': 'Bearer $accessToken',
    _businessHeader: ?businessId,
  };

  /// Hace la petición y devuelve el cuerpo JSON de una respuesta correcta
  /// (`null` si no trae cuerpo).
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? accessToken,
    String? businessId,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(
        _headers(accessToken: accessToken, businessId: businessId),
      );
    if (body != null) {
      request
        ..headers['content-type'] = 'application/json; charset=utf-8'
        ..bodyBytes = utf8.encode(jsonEncode(body));
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException catch (e) {
      throw NetworkException(e);
    } on SocketException catch (e) {
      throw NetworkException(e);
    } on http.ClientException catch (e) {
      throw NetworkException(e);
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return text.isEmpty ? null : _decode(text, response.statusCode);
    }
    throw _errorOf(response.statusCode, text);
  }

  Object? _decode(String text, int status) {
    try {
      return jsonDecode(text);
    } on FormatException {
      throw ApiException(status, ApiException.invalidResponse);
    }
  }

  ApiException _errorOf(int status, String text) {
    try {
      final error = ApiError.fromJson(jsonDecode(text) as Map<String, dynamic>);
      return ApiException(status, error.code, error.codes);
    } on Object {
      return ApiException(status, ApiException.unexpectedResponse);
    }
  }

  /// Lee el cuerpo con [parse]; un cuerpo que no cumple el contrato es una
  /// respuesta inválida, no un fallo de programación.
  T _parse<T>(Object? json, int okStatus, T Function(Object?) parse) {
    try {
      return parse(json);
    } on Object {
      throw ApiException(okStatus, ApiException.invalidResponse);
    }
  }

  @override
  Future<RegisteredAccount> register({
    required String email,
    required String password,
    required String businessName,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async => _parse(
    await _send(
      'POST',
      '/api/auth/register',
      body: {
        'email': email,
        'password': password,
        'businessName': businessName,
        'amountMode': amountMode.id,
        'quantityMode': quantityMode.id,
      },
    ),
    201,
    (j) => RegisteredAccount.fromJson(j! as Map<String, dynamic>),
  );

  @override
  Future<ApiTokens> login(String email, String password) async => _parse(
    await _send(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    ),
    200,
    (j) => ApiTokens.fromJson(j! as Map<String, dynamic>),
  );

  @override
  Future<ApiTokens> refresh(String refreshToken) async => _parse(
    await _send(
      'POST',
      '/api/auth/refresh',
      body: {'refreshToken': refreshToken},
    ),
    200,
    (j) => ApiTokens.fromJson(j! as Map<String, dynamic>),
  );

  @override
  Future<void> logout(String accessToken) async {
    await _send('POST', '/api/auth/logout', accessToken: accessToken);
  }

  @override
  Future<List<RemoteBusiness>> listBusinesses(String accessToken) async =>
      _parse(
        await _send('GET', '/api/businesses', accessToken: accessToken),
        200,
        (j) => [
          for (final b in j! as List<dynamic>)
            RemoteBusiness.fromJson(b as Map<String, dynamic>),
        ],
      );

  @override
  Future<RemoteBusiness> createBusiness(
    String accessToken, {
    required String name,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async => _parse(
    await _send(
      'POST',
      '/api/businesses',
      accessToken: accessToken,
      body: {
        'name': name,
        'amountMode': amountMode.id,
        'quantityMode': quantityMode.id,
      },
    ),
    201,
    (j) => RemoteBusiness.fromJson(j! as Map<String, dynamic>),
  );

  @override
  Future<List<OperationResult>> push(
    String accessToken,
    String businessId,
    List<PushOperation> operations,
  ) async => _parse(
    await _send(
      'POST',
      '/api/sync/push',
      accessToken: accessToken,
      businessId: businessId,
      body: {
        'operations': [for (final o in operations) o.toJson()],
      },
    ),
    200,
    (j) => [
      for (final r in (j! as Map<String, dynamic>)['results'] as List<dynamic>)
        OperationResult.fromJson(r as Map<String, dynamic>),
    ],
  );

  @override
  Future<PullPage> pull(
    String accessToken,
    String businessId, {
    required int cursor,
    int? limit,
  }) async => _parse(
    await _send(
      'GET',
      '/api/sync/pull',
      accessToken: accessToken,
      businessId: businessId,
      query: {'cursor': '$cursor', if (limit != null) 'limit': '$limit'},
    ),
    200,
    (j) => PullPage.fromJson(j! as Map<String, dynamic>),
  );
}
