import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_service.dart';
import 'providers.dart';
import 'session_state.dart';

/// Qué pidió sincronizar (RF-52).
enum SyncTrigger { open, reconnect, manual }

/// Cómo va la sincronización del negocio activo.
final class SyncStatus {
  const SyncStatus({this.running = false, this.last});

  final bool running;

  /// Cómo terminó la última vuelta; null si aún no hubo ninguna.
  final SyncOutcome? last;

  /// ¿Hay que iniciar sesión para poder sincronizar? (D-10: la app sigue
  /// usable y la cola se conserva.)
  bool get needsLogin =>
      last is SyncFailed &&
      (last! as SyncFailed).reason == SyncFailure.sessionExpired;

  /// Ediciones locales descartadas en la última vuelta por conflicto (RF-55).
  int get conflicts => switch (last) {
    SyncSucceeded(:final report) => report.push.conflicts,
    _ => 0,
  };

  SyncStatus copyWith({bool? running, SyncOutcome? last}) =>
      SyncStatus(running: running ?? this.running, last: last ?? this.last);
}

/// Cuenta las veces que cambió la base local por una sincronización. Las
/// listas de la interfaz la observan para volver a leer (los `FutureProvider`
/// no se refrescan solos).
final localDataRevisionProvider = NotifierProvider<LocalDataRevision, int>(
  LocalDataRevision.new,
);

class LocalDataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

/// Sincroniza el negocio activo cuando se lo piden los disparadores (al abrir,
/// al recuperar la conexión, a mano) y publica el estado.
class SyncController extends Notifier<SyncStatus> {
  Future<SyncOutcome?>? _current;

  @override
  SyncStatus build() => const SyncStatus();

  /// Inicia una sincronización, o se suma a la que ya está en marcha. Sin
  /// negocio elegido no hace nada. El disparo manual lo intenta una vez para
  /// responder enseguida; los automáticos reintentan si falla la red.
  Future<SyncOutcome?> request(SyncTrigger trigger) =>
      _current ??= _run(trigger).whenComplete(() {
        _current = null;
      });

  Future<SyncOutcome?> _run(SyncTrigger trigger) async {
    final session = ref.read(sessionControllerProvider).value;
    final businessId = session is SignedIn ? session.active?.id : null;
    if (businessId == null) {
      return null;
    }
    final service = ref.read(syncServiceProvider);
    state = state.copyWith(running: true);
    final outcome = trigger == SyncTrigger.manual
        ? await service.attempt(businessId)
        : await service.syncWithRetries(businessId);
    if (outcome is SyncSucceeded && outcome.report.changedLocalData) {
      ref.read(localDataRevisionProvider.notifier).bump();
    }
    state = SyncStatus(last: outcome);
    return outcome;
  }
}

/// ¿Hay conexión? Emite cada vez que cambia (connectivity_plus). Que el
/// sistema diga que hay red no asegura que el servidor responda; sirve de
/// disparador, y si falla, la sincronización reintenta.
final onlineProvider = StreamProvider<bool>(
  (ref) => Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  ),
);
