import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../remote/api_client.dart';
import '../remote/models.dart';
import 'session_store.dart';

/// No hay sesión utilizable: no se ha iniciado, o el token de renovación ya
/// caducó. Hace falta iniciar sesión de nuevo (D-10).
class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'SessionExpiredException';
}

/// Se intentó volver a entrar con una cuenta distinta de la del teléfono.
class WrongAccountException implements Exception {
  const WrongAccountException();

  @override
  String toString() => 'WrongAccountException';
}

/// La sesión del usuario en este teléfono: registrarse, iniciar y cerrar sesión
/// y mantener el token de acceso vigente. No conoce la interfaz ni Riverpod.
class SessionService {
  SessionService({
    required this._api,
    required this._store,
    required this._now,
  });

  /// Cuánto antes de caducar se renueva el token de acceso.
  static const renewMargin = Duration(seconds: 30);

  final PulperiaApi _api;
  final SessionStore _store;
  final DateTime Function() _now;

  /// La sesión guardada, si la hay. No necesita red (RF-3).
  Future<StoredSession?> restore() => _store.read();

  /// Crea la cuenta con su primer negocio (RF-1, RF-2, RF-78) e inicia sesión,
  /// porque el registro no devuelve tokens. Requiere conexión.
  Future<StoredSession> register({
    required String email,
    required String password,
    required String businessName,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async {
    final normalized = _normalize(email);
    await _api.register(
      email: normalized,
      password: password,
      businessName: businessName.trim(),
      amountMode: amountMode,
      quantityMode: quantityMode,
    );
    return login(normalized, password);
  }

  /// Crea la cuenta de quien solo viene a trabajar con un código de invitación
  /// (RF-105): sin negocio propio, como empleado del negocio de la invitación, e
  /// inicia sesión. Requiere conexión. Si el código no sirve no se crea nada.
  Future<StoredSession> registerWithInvitationCode({
    required String email,
    required String password,
    required String invitationCode,
  }) async {
    final normalized = _normalize(email);
    await _api.registerWithInvitationCode(
      email: normalized,
      password: password,
      invitationCode: invitationCode.trim(),
    );
    return login(normalized, password);
  }

  /// Inicia sesión (RF-3). El primer inicio en un teléfono requiere conexión
  /// (principio 2): sin ella lanza [NetworkException] y no guarda nada.
  Future<StoredSession> login(String email, String password) async {
    final normalized = _normalize(email);
    final tokens = await _api.login(normalized, password);
    final session = StoredSession(
      userId: tokens.userId,
      email: normalized,
      tokens: tokens,
    );
    await _store.write(session);
    return session;
  }

  /// Vuelve a entrar con la contraseña cuando el token de renovación caducó
  /// sin conexión (D-10): reemplaza los tokens y conserva el negocio activo y
  /// todo lo demás del teléfono, incluida la cola. Solo vale para el mismo
  /// usuario: otro enviaría los cambios pendientes con su nombre.
  Future<StoredSession> reauthenticate(String password) async {
    final session = await _store.read();
    if (session == null) {
      throw const SessionExpiredException();
    }
    final tokens = await _api.login(session.email, password);
    if (tokens.userId != session.userId) {
      throw const WrongAccountException();
    }
    final renewed = session.copyWith(tokens: tokens);
    await _store.write(renewed);
    return renewed;
  }

  /// Cierra la sesión. Avisa al servidor si puede, pero la sesión del teléfono
  /// se borra aunque no haya red.
  Future<void> logout() async {
    final session = await _store.read();
    if (session != null) {
      try {
        await _api.logout(session.tokens.accessToken);
      } on ApiException {
        // El servidor ya no la reconoce o no responde bien: da igual.
      } on NetworkException {
        // Sin red: se cierra aquí; el token de acceso caduca solo.
      }
    }
    await _store.clear();
  }

  /// Recuerda con qué negocio trabaja el usuario (o ninguno).
  Future<StoredSession?> saveActiveBusiness(RemoteBusiness? business) async {
    final session = await _store.read();
    if (session == null) {
      return null;
    }
    final updated = business == null
        ? session.copyWith(clearActiveBusiness: true)
        : session.copyWith(activeBusiness: business);
    await _store.write(updated);
    return updated;
  }

  /// El token de acceso vigente, renovándolo si está por caducar. La renovación
  /// reemplaza los dos tokens (D-27).
  ///
  /// Lanza [SessionExpiredException] si no hay sesión o el token de renovación
  /// ya caducó, [NetworkException] si no se pudo renovar por falta de red (lo
  /// guardado no cambia) y [ApiException] si el servidor rechazó la renovación.
  Future<String> accessToken() async {
    final session = await _store.read();
    if (session == null) {
      throw const SessionExpiredException();
    }
    final tokens = session.tokens;
    if (tokens.accessExpiresAt.difference(_now()) > renewMargin) {
      return tokens.accessToken;
    }
    if (!tokens.refreshExpiresAt.isAfter(_now())) {
      throw const SessionExpiredException();
    }

    final renewed = await _api.refresh(tokens.refreshToken);
    await _store.write(session.copyWith(tokens: renewed));
    return renewed.accessToken;
  }

  static String _normalize(String email) => email.trim().toLowerCase();
}
