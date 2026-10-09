import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session/session_store.dart';
import '../domain/business/amount_mode.dart';
import '../domain/business/quantity_mode.dart';
import 'providers.dart';
import 'session_state.dart';

/// La sesión de este teléfono para la interfaz. Los errores de una acción
/// (credenciales malas, sin red) se lanzan a quien la pidió, que decide cómo
/// mostrarlos; el estado solo cambia cuando la acción tiene éxito.
class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async =>
      _stateOf(await ref.watch(sessionServiceProvider).restore());

  static SessionState _stateOf(StoredSession? stored) => stored == null
      ? const SignedOut()
      : SignedIn(
          userId: stored.userId,
          email: stored.email,
          active: stored.activeBusiness,
        );

  /// Inicia sesión (RF-3). Requiere conexión la primera vez en el teléfono.
  Future<void> login(String email, String password) async {
    final stored = await ref
        .read(sessionServiceProvider)
        .login(email, password);
    state = AsyncData(_stateOf(stored));
  }

  /// Crea la cuenta con su primer negocio e inicia sesión (RF-1, RF-2, RF-78).
  Future<void> register({
    required String email,
    required String password,
    required String businessName,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async {
    final stored = await ref
        .read(sessionServiceProvider)
        .register(
          email: email,
          password: password,
          businessName: businessName,
          amountMode: amountMode,
          quantityMode: quantityMode,
        );
    state = AsyncData(_stateOf(stored));
  }

  /// Cierra la sesión de este teléfono.
  Future<void> logout() async {
    await ref.read(sessionServiceProvider).logout();
    state = const AsyncData(SignedOut());
  }
}
