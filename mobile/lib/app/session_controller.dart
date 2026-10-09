import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/models.dart';
import '../data/session/session_store.dart';
import '../data/sync/sync_service.dart';
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
    await _chooseOnlyBusiness();
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
    await _chooseOnlyBusiness();
  }

  /// Cierra la sesión de este teléfono. Con cambios sin enviar no se puede:
  /// otro usuario los enviaría con su nombre, así que primero hay que
  /// sincronizar (lanza [PendingChangesException] con cuántos faltan).
  Future<void> logout() async {
    final pending = await ref.read(syncServiceProvider).pendingCount();
    if (pending > 0) {
      throw PendingChangesException(pending);
    }
    await ref.read(sessionServiceProvider).logout();
    state = const AsyncData(SignedOut());
  }

  SignedIn get _signedIn => switch (state.value) {
    final SignedIn current => current,
    _ => throw StateError('No hay sesión iniciada'),
  };

  /// Los negocios del usuario (RF-5): los del servidor si hay red, y si no los
  /// guardados en el teléfono. Con red, además, pone al día el negocio activo
  /// (nombre, rol, modos) y lo quita si el usuario ya no pertenece a él.
  Future<List<RemoteBusiness>> loadBusinesses() async {
    final service = ref.read(businessServiceProvider);
    final List<RemoteBusiness> list;
    try {
      list = await service.refresh();
    } on NetworkException {
      return service.local();
    }
    await _reconcileActive(list);
    return list;
  }

  /// Elige el negocio con el que trabajar (RF-6). Todo lo que se muestra y se
  /// escribe pasa a ser de ese negocio.
  Future<void> chooseBusiness(RemoteBusiness business) async {
    await ref.read(businessServiceProvider).select(business);
    state = AsyncData(_withActive(business));
  }

  /// Crea un negocio adicional (RF-79) y lo elige. Requiere conexión.
  Future<void> createBusiness({
    required String name,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async {
    final created = await ref
        .read(businessServiceProvider)
        .create(name: name, amountMode: amountMode, quantityMode: quantityMode);
    await chooseBusiness(created);
  }

  SessionState _withActive(RemoteBusiness? business) {
    final current = _signedIn;
    return SignedIn(
      userId: current.userId,
      email: current.email,
      active: business,
    );
  }

  Future<void> _reconcileActive(List<RemoteBusiness> list) async {
    final active = _signedIn.active;
    if (active == null) {
      return;
    }
    final fresh = list.where((b) => b.id == active.id).firstOrNull;
    if (fresh == null) {
      await ref.read(sessionServiceProvider).saveActiveBusiness(null);
      state = AsyncData(_withActive(null));
    } else if (fresh.toJson().toString() != active.toJson().toString()) {
      await chooseBusiness(fresh);
    }
  }

  /// Si el usuario tiene un solo negocio no hace falta preguntarle cuál. Si no
  /// se puede saber (sin red), la pantalla de elección lo resuelve después.
  Future<void> _chooseOnlyBusiness() async {
    try {
      final list = await loadBusinesses();
      if (list.length == 1 && _signedIn.active == null) {
        await chooseBusiness(list.single);
      }
    } on Object {
      // Se queda sin negocio elegido; la pantalla de elección lo carga.
    }
  }
}
