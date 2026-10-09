import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../remote/models.dart';

/// Lo que la app recuerda entre arranques de la sesión iniciada: quién es, sus
/// tokens y con qué negocio trabaja. Vive en el almacenamiento seguro del
/// sistema, nunca en la base local (plan 3.2, D-31).
final class StoredSession {
  const StoredSession({
    required this.userId,
    required this.email,
    required this.tokens,
    this.activeBusiness,
  });

  factory StoredSession.fromJson(Map<String, dynamic> json) => StoredSession(
    userId: json['userId'] as String,
    email: json['email'] as String,
    tokens: ApiTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    activeBusiness: json['activeBusiness'] == null
        ? null
        : RemoteBusiness.fromJson(
            json['activeBusiness'] as Map<String, dynamic>,
          ),
  );

  final String userId;
  final String email;
  final ApiTokens tokens;

  /// El negocio con el que trabaja, tal como lo conocía el servidor al elegirlo.
  final RemoteBusiness? activeBusiness;

  StoredSession copyWith({
    ApiTokens? tokens,
    RemoteBusiness? activeBusiness,
    bool clearActiveBusiness = false,
  }) => StoredSession(
    userId: userId,
    email: email,
    tokens: tokens ?? this.tokens,
    activeBusiness: clearActiveBusiness
        ? null
        : activeBusiness ?? this.activeBusiness,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'tokens': tokens.toJson(),
    'activeBusiness': activeBusiness?.toJson(),
  };
}

/// Dónde se guarda la sesión. Una interfaz para que las pruebas usen una en
/// memoria.
abstract interface class SessionStore {
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  Future<void> clear();
}

/// La sesión en el Keystore de Android / llavero de iOS, como un solo valor.
final class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'pulperia.session';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final text = await _storage.read(key: _key);
    if (text == null) {
      return null;
    }
    try {
      return StoredSession.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on Object {
      // Un valor que ya no se entiende (por ejemplo de una versión anterior)
      // se trata como si no hubiera sesión: se vuelve a iniciar.
      await _storage.delete(key: _key);
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
