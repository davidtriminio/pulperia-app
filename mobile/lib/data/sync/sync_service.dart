import 'dart:convert';

import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../remote/api_client.dart';
import '../remote/models.dart';
import '../session/session_service.dart';
import 'change_applier.dart';

/// Hay cambios hechos en este teléfono que aún no llegaron al servidor, así
/// que no se puede cerrar la sesión: otro usuario los enviaría con su nombre
/// (el servidor pone como autor al dueño del token).
class PendingChangesException implements Exception {
  const PendingChangesException(this.count);

  /// Cuántas operaciones faltan por enviar.
  final int count;

  @override
  String toString() => 'PendingChangesException($count)';
}

/// Lo que pasó al enviar la cola de un negocio.
final class PushReport {
  const PushReport({this.sent = 0, this.rejected = 0, this.conflicts = 0});

  /// Operaciones que el servidor aplicó o ya tenía (salen de la cola).
  final int sent;

  /// Operaciones que el servidor rechazó (se quedan visibles con su código).
  final int rejected;

  /// De las rechazadas, las que fueron por conflicto de versión (RF-55).
  final int conflicts;
}

/// Lo que pasó al recibir los cambios del servidor.
final class PullReport {
  const PullReport({this.received = 0});

  /// Cuántos registros entregó el servidor.
  final int received;
}

/// El resultado de una vuelta de sincronización.
final class SyncReport {
  const SyncReport({required this.push, required this.pull});

  final PushReport push;
  final PullReport pull;

  /// ¿Cambió algo en la base local que la pantalla deba volver a leer?
  bool get changedLocalData =>
      push.sent > 0 || push.rejected > 0 || pull.received > 0;
}

/// Cómo terminó un intento de sincronizar.
sealed class SyncOutcome {
  const SyncOutcome();
}

final class SyncSucceeded extends SyncOutcome {
  const SyncSucceeded(this.report);

  final SyncReport report;
}

/// Por qué no se pudo sincronizar.
enum SyncFailure {
  /// Sin conexión o sin respuesta a tiempo.
  network,

  /// El servidor falló o respondió algo ilegible: se reintenta más tarde.
  server,

  /// El servidor no admite la petición (sin permiso, negocio dado de baja...).
  refused,

  /// No hay sesión utilizable: hay que iniciar sesión para sincronizar (D-10).
  sessionExpired,

  /// Ya no perteneces al negocio (RF-11): sus datos locales se borraron.
  removed,

  /// El negocio espera que un super administrador lo active (RF-102): la cola
  /// se conserva y se envía al activarse.
  businessPending,

  /// El negocio está suspendido (RF-98): el teléfono sigue con lo que tiene y
  /// la cola se conserva hasta que se reactive.
  businessSuspended,
}

final class SyncFailed extends SyncOutcome {
  const SyncFailed(this.reason, {this.code});

  final SyncFailure reason;

  /// El código del servidor, cuando lo hubo.
  final String? code;

  /// ¿Tiene sentido volver a intentarlo sin que el usuario haga nada?
  bool get retryable =>
      reason == SyncFailure.network || reason == SyncFailure.server;
}

/// La sincronización de un negocio con el servidor (plan, sección 4): envía la
/// cola de cambios locales por lotes y recibe los cambios de los demás por
/// cursor. No conoce la interfaz ni Riverpod.
class SyncService {
  SyncService({
    required this.sessions,
    required this.api,
    required this.db,
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  /// Esperas entre un intento y el siguiente cuando falla la red o el
  /// servidor (RF-56): son los reintentos que se hacen en la misma
  /// sincronización; si todos fallan, se vuelve a intentar con el siguiente
  /// disparador (al abrir, al recuperar conexión, a mano).
  static const retryDelays = [Duration(seconds: 2), Duration(seconds: 6)];

  /// El servidor rechaza lotes de más operaciones que esto (`batch_too_large`).
  static const maxBatch = 500;

  /// Código con el que el servidor rechaza una edición hecha sobre una versión
  /// vieja (D-8).
  static const versionConflict = 'version_conflict';

  final SessionService sessions;
  final PulperiaApi api;
  final AppDatabase db;
  final Future<void> Function(Duration) _wait;

  final Map<String, Future<SyncOutcome>> _running = {};

  /// Una vuelta de sincronización que no lanza: cualquier fallo se devuelve
  /// como [SyncFailed], con la cola intacta (RF-56). Si ya hay una vuelta en
  /// marcha para ese negocio se comparte su resultado en vez de empezar otra.
  Future<SyncOutcome> attempt(String businessId) =>
      _running[businessId] ??= _attempt(businessId).whenComplete(() {
        // Sin devolver el valor de `remove`: `whenComplete` esperaría a esa
        // misma vuelta y no terminaría nunca.
        _running.remove(businessId);
      });

  Future<SyncOutcome> _attempt(String businessId) async {
    try {
      return SyncSucceeded(await sync(businessId));
    } on SessionExpiredException {
      return const SyncFailed(SyncFailure.sessionExpired);
    } on NetworkException {
      return const SyncFailed(SyncFailure.network);
    } on ApiException catch (e) {
      if (e.status == 401) {
        return const SyncFailed(SyncFailure.sessionExpired);
      }
      // El negocio existe y es del usuario, pero no está activo: no es una baja.
      if (e.status == 403 && e.code == businessPendingCode) {
        return const SyncFailed(
          SyncFailure.businessPending,
          code: businessPendingCode,
        );
      }
      if (e.status == 403 && e.code == businessSuspendedCode) {
        return const SyncFailed(
          SyncFailure.businessSuspended,
          code: businessSuspendedCode,
        );
      }
      if (e.status == 403 && e.code == forbiddenCode) {
        return _confirmRemoval(businessId, e);
      }
      // Un 5xx, un tiempo agotado o una respuesta que no es el contrato son
      // del servidor y pasan solos; lo demás (403, 401...) es que no nos deja.
      final transient =
          e.status >= 500 ||
          e.status == 408 ||
          e.status == 429 ||
          e.code == ApiException.invalidResponse ||
          e.code == ApiException.unexpectedResponse;
      return transient
          ? SyncFailed(SyncFailure.server, code: e.code)
          : SyncFailed(SyncFailure.refused, code: e.code);
    }
  }

  /// Código con el que el servidor niega el acceso al negocio.
  static const forbiddenCode = 'forbidden';

  /// Códigos con los que un negocio no activo rechaza la sincronización (D-30).
  static const businessPendingCode = 'business_pending';
  static const businessSuspendedCode = 'business_suspended';

  /// El servidor negó el acceso: si de verdad ya no pertenecemos al negocio
  /// (RF-11), se borran sus datos locales, y el último lote ya se envió antes
  /// (RF-12). Se comprueba con la lista de negocios del usuario para no borrar
  /// por un 403 que sea otra cosa; si no se puede comprobar, no se borra.
  Future<SyncOutcome> _confirmRemoval(String businessId, ApiException e) async {
    final List<RemoteBusiness> mine;
    try {
      mine = await api.listBusinesses(await sessions.accessToken());
    } on SessionExpiredException {
      return const SyncFailed(SyncFailure.sessionExpired);
    } on NetworkException {
      return const SyncFailed(SyncFailure.network);
    } on ApiException catch (other) {
      return other.status == 401
          ? const SyncFailed(SyncFailure.sessionExpired)
          : SyncFailed(SyncFailure.server, code: other.code);
    }
    if (mine.any((b) => b.id == businessId)) {
      return SyncFailed(SyncFailure.refused, code: e.code);
    }
    await purgeBusiness(businessId);
    return const SyncFailed(SyncFailure.removed);
  }

  /// Borra todo lo que el teléfono guarda de un negocio: sus datos, su cola,
  /// su cursor y la pertenencia (RF-11).
  Future<void> purgeBusiness(String businessId) => db.transaction(() async {
    await (db.delete(
      db.fiadoItems,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.fiados,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.payments,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.products,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.clients,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.outboxOps,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.syncStates,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.memberships,
    )..where((t) => t.businessId.equals(businessId))).go();
    await (db.delete(
      db.businesses,
    )..where((t) => t.id.equals(businessId))).go();
  });

  /// Como [attempt], pero si falla la red o el servidor espera un poco y
  /// vuelve a intentar, hasta agotar [retryDelays]. Lo que no se arregla
  /// reintentando (sesión caducada, petición rechazada) no se reintenta.
  Future<SyncOutcome> syncWithRetries(String businessId) async {
    var outcome = await attempt(businessId);
    for (final delay in retryDelays) {
      if (outcome is! SyncFailed || !outcome.retryable) {
        break;
      }
      await _wait(delay);
      outcome = await attempt(businessId);
    }
    return outcome;
  }

  /// Una vuelta completa de sincronización de un negocio: primero envía lo
  /// pendiente y después recibe lo de los demás, para que una edición local
  /// rechazada por conflicto ya encuentre la versión del servidor al recibir
  /// (RF-55). En un dispositivo nuevo la cola está vacía y el cursor en cero,
  /// así que esto es la descarga inicial (RF-58). Si algo falla, la
  /// excepción sube y la cola queda como estaba (RF-56).
  Future<SyncReport> sync(String businessId) async {
    final push = await pushPending(businessId);
    final pull = await pullChanges(businessId);
    return SyncReport(push: push, pull: pull);
  }

  /// Sincroniza todos los negocios que tienen cambios sin enviar (el teléfono
  /// puede guardar los de varios), uno tras otro. Cada negocio se intenta
  /// aunque otro falle; el resultado es por negocio.
  Future<Map<String, SyncOutcome>> syncAllPending() async {
    final column = db.outboxOps.businessId;
    final rows =
        await (db.selectOnly(db.outboxOps, distinct: true)
              ..addColumns([column])
              ..where(db.outboxOps.status.equals('pending')))
            .get();
    final outcomes = <String, SyncOutcome>{};
    for (final row in rows) {
      final id = row.read(column)!;
      outcomes[id] = await attempt(id);
    }
    return outcomes;
  }

  /// Operaciones pendientes de enviar (RF-57): las de un negocio, o las de
  /// todos si no se indica. Las rechazadas no cuentan: ya no se reenvían.
  Future<int> pendingCount({String? businessId}) async {
    final count = db.outboxOps.localSeq.count();
    final query = db.selectOnly(db.outboxOps)
      ..addColumns([count])
      ..where(db.outboxOps.status.equals('pending'));
    if (businessId != null) {
      query.where(db.outboxOps.businessId.equals(businessId));
    }
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Envía las operaciones pendientes del negocio, en orden de creación y por
  /// tandas (RF-52). Cada resultado se aplica a la cola al recibirlo: las
  /// aplicadas y duplicadas salen, las rechazadas quedan con su código
  /// (RF-53, RF-56). Si una tanda falla, las anteriores ya quedaron resueltas
  /// y el resto sigue pendiente; la excepción sube a quien llamó.
  Future<PushReport> pushPending(String businessId) async {
    var sent = 0;
    var rejected = 0;
    var conflicts = 0;

    while (true) {
      final batch = await _nextBatch(businessId);
      if (batch.isEmpty) {
        break;
      }
      final results = await api.push(await sessions.accessToken(), businessId, [
        for (final op in batch) _toPush(op),
      ]);
      final byId = {for (final r in results) r.opId: r};

      var resolved = 0;
      await db.transaction(() async {
        for (final op in batch) {
          final result = byId[op.opId];
          if (result == null) {
            continue;
          }
          resolved++;
          switch (result.status) {
            case OperationStatus.applied || OperationStatus.duplicate:
              sent++;
              await (db.delete(
                db.outboxOps,
              )..where((o) => o.opId.equals(op.opId))).go();
            case OperationStatus.rejected:
              rejected++;
              final code = result.code ?? 'unknown';
              if (code == versionConflict) {
                conflicts++;
              }
              await (db.update(
                db.outboxOps,
              )..where((o) => o.opId.equals(op.opId))).write(
                OutboxOpsCompanion(
                  status: const Value('rejected'),
                  errorCode: Value(code),
                ),
              );
              if (code == versionConflict) {
                // Las ediciones seguidas sobre ese registro partían de la
                // descartada: también se descartan, sin enviarlas.
                final chained =
                    await (db.update(db.outboxOps)..where(
                          (o) =>
                              o.businessId.equals(businessId) &
                              o.entityId.equals(op.entityId) &
                              o.status.equals('pending') &
                              o.localSeq.isBiggerThanValue(op.localSeq) &
                              o.baseVersion.isNotNull(),
                        ))
                        .write(
                          const OutboxOpsCompanion(
                            status: Value('rejected'),
                            errorCode: Value(versionConflict),
                          ),
                        );
                rejected += chained;
                conflicts += chained;
              }
          }
        }
      });
      if (resolved == 0) {
        // El servidor no contestó por ninguna: no se insiste en este ciclo.
        break;
      }
    }
    return PushReport(sent: sent, rejected: rejected, conflicts: conflicts);
  }

  /// Recibe los cambios de los demás dispositivos desde el cursor guardado
  /// (RF-52): pide todas las páginas y las aplica juntas, con el cursor nuevo,
  /// en una sola transacción (todo o nada). Con cursor cero es la descarga
  /// inicial (RF-58).
  ///
  /// Si algo falla antes de aplicar, no queda nada a medias y el cursor no
  /// avanza; la excepción sube a quien llamó.
  Future<PullReport> pullChanges(String businessId, {int? pageSize}) async {
    final start = await _cursorOf(businessId);
    final changes = <RemoteChange>[];
    var cursor = start;
    while (true) {
      final page = await api.pull(
        await sessions.accessToken(),
        businessId,
        cursor: cursor,
        limit: pageSize,
      );
      changes.addAll(page.changes);
      if (page.hasMore && page.cursor <= cursor) {
        // Un servidor que promete más sin avanzar nos dejaría dando vueltas.
        throw const ApiException(200, ApiException.invalidResponse);
      }
      cursor = page.cursor;
      if (!page.hasMore) {
        break;
      }
    }

    await db.transaction(() async {
      await ChangeApplier(db).apply(businessId, changes);
      await db
          .into(db.syncStates)
          .insertOnConflictUpdate(
            SyncStatesCompanion.insert(
              businessId: businessId,
              cursor: Value(cursor),
            ),
          );
    });
    return PullReport(received: changes.length);
  }

  Future<int> _cursorOf(String businessId) async {
    final row = await (db.select(
      db.syncStates,
    )..where((s) => s.businessId.equals(businessId))).getSingleOrNull();
    return row?.cursor ?? 0;
  }

  /// Las operaciones rechazadas del negocio, en orden de creación: lo que el
  /// usuario debe saber que no se aplicó (el código dice por qué; por
  /// ejemplo, `version_conflict` es una edición descartada, RF-55).
  Future<List<OutboxOp>> rejectedOperations(String businessId) =>
      (db.select(db.outboxOps)
            ..where(
              (o) =>
                  o.businessId.equals(businessId) & o.status.equals('rejected'),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.localSeq)]))
          .get();

  /// Descarta un cambio rechazado por el servidor (el usuario ya lo vio). Un
  /// fiado o abono rechazado se borra del teléfono, porque el servidor nunca lo
  /// tuvo y sumaría al saldo para siempre; un cliente o producto creado y
  /// rechazado se borra si nada lo usa; en una edición rechazada se vuelve a
  /// pedir al servidor su versión (cursor en cero). Devuelve false si no hay
  /// un cambio rechazado con ese id: lo pendiente no se descarta.
  Future<bool> discardRejected(String opId) => db.transaction(() async {
    final op =
        await (db.select(db.outboxOps)
              ..where((o) => o.opId.equals(opId) & o.status.equals('rejected')))
            .getSingleOrNull();
    if (op == null) {
      return false;
    }
    final business = op.businessId;
    final entity = op.entityId;
    switch (op.type) {
      case 'fiado.create':
        await (db.delete(
          db.fiadoItems,
        )..where((t) => t.fiadoId.equals(entity))).go();
        await (db.delete(db.fiados)..where((t) => t.id.equals(entity))).go();
      case 'payment.create':
        await (db.delete(db.payments)..where((t) => t.id.equals(entity))).go();
      case 'client.create':
        final used =
            (await (db.select(
              db.fiados,
            )..where((t) => t.clientId.equals(entity))).get()).isNotEmpty ||
            (await (db.select(
              db.payments,
            )..where((t) => t.clientId.equals(entity))).get()).isNotEmpty;
        if (!used) {
          await (db.delete(db.clients)..where((t) => t.id.equals(entity))).go();
        }
      case 'product.create':
        final used = (await (db.select(
          db.fiadoItems,
        )..where((t) => t.productId.equals(entity))).get()).isNotEmpty;
        if (!used) {
          await (db.delete(
            db.products,
          )..where((t) => t.id.equals(entity))).go();
        }
      default:
        // Edición, archivado, restauración o anulación: la base local pudo
        // quedar distinta de la del servidor, así que se vuelve a bajar.
        await (db.update(db.syncStates)
              ..where((t) => t.businessId.equals(business)))
            .write(const SyncStatesCompanion(cursor: Value(0)));
    }
    await (db.delete(db.outboxOps)..where((o) => o.opId.equals(opId))).go();
    return true;
  });

  /// La siguiente tanda: las pendientes en orden de creación, hasta el tope.
  /// De varias ediciones seguidas sobre el mismo registro solo va la primera:
  /// las demás parten de una versión que el servidor decide si existió, así
  /// que esperan a la siguiente tanda (o se descartan si hubo conflicto).
  Future<List<OutboxOp>> _nextBatch(String businessId) async {
    final pending =
        await (db.select(db.outboxOps)
              ..where(
                (o) =>
                    o.businessId.equals(businessId) &
                    o.status.equals('pending'),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.localSeq)]))
            .get();
    final editing = <String>{};
    final batch = <OutboxOp>[];
    for (final op in pending) {
      if (op.baseVersion != null && !editing.add(op.entityId)) {
        continue;
      }
      batch.add(op);
      if (batch.length == maxBatch) {
        break;
      }
    }
    return batch;
  }

  PushOperation _toPush(OutboxOp op) => PushOperation(
    opId: op.opId,
    type: op.type,
    entityId: op.entityId,
    payload: jsonDecode(op.payload) as Map<String, dynamic>,
    baseVersion: op.baseVersion,
    createdAt: op.createdAt,
  );
}
