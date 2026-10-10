import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_service.dart';
import '../domain/business/business_status.dart';
import '../data/local/app_database.dart';
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
    if (outcome is SyncFailed) {
      // El negocio no está activo (D-30): se recuerda en la sesión, con la cola intacta.
      final unavailable = switch (outcome.reason) {
        SyncFailure.businessPending => BusinessStatus.pending,
        SyncFailure.businessSuspended => BusinessStatus.suspended,
        _ => null,
      };
      if (unavailable != null) {
        await ref
            .read(sessionControllerProvider.notifier)
            .markActiveStatus(unavailable);
      }
    }
    if (outcome is SyncFailed && outcome.reason == SyncFailure.removed) {
      // Sus datos ya se borraron: se sale del negocio y se avisa.
      ref
          .read(removedBusinessProvider.notifier)
          .set(session is SignedIn ? session.active?.name : null);
      await ref.read(sessionControllerProvider.notifier).leaveActiveBusiness();
      ref.read(localDataRevisionProvider.notifier).bump();
    }
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

/// Cuántos cambios del negocio activo faltan por enviar (RF-57). Se actualiza
/// sola cuando cambia la cola, tanto al guardar algo como al sincronizar.
///
/// Escucha los avisos de cambio de la tabla en vez de una consulta observada
/// de Drift: así no deja temporizadores pendientes al cerrarse en los tests.
final pendingChangesProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  Future<int> count() =>
      ref.read(syncServiceProvider).pendingCount(businessId: businessId);

  yield await count();
  await for (final _ in db.tableUpdates(
    TableUpdateQuery.onTable(db.outboxOps),
  )) {
    yield await count();
  }
});

/// El nombre del negocio al que el usuario perdió el acceso (RF-11), para
/// avisárselo al elegir negocio. Null si no hay nada que avisar.
final removedBusinessProvider = NotifierProvider<RemovedBusiness, String?>(
  RemovedBusiness.new,
);

class RemovedBusiness extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? name) => state = name;
}

/// Los cambios del negocio activo que el servidor rechazó, en orden de
/// creación. Se actualiza sola cuando cambia la cola.
final rejectedChangesProvider = StreamProvider<List<OutboxOp>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  Future<List<OutboxOp>> load() =>
      ref.read(syncServiceProvider).rejectedOperations(businessId);

  yield await load();
  await for (final _ in db.tableUpdates(
    TableUpdateQuery.onTable(db.outboxOps),
  )) {
    yield await load();
  }
});
