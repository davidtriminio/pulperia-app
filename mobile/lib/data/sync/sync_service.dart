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

/// La sincronización de un negocio con el servidor (plan, sección 4): envía la
/// cola de cambios locales por lotes y recibe los cambios de los demás por
/// cursor. No conoce la interfaz ni Riverpod.
class SyncService {
  SyncService({required this.sessions, required this.api, required this.db});

  /// El servidor rechaza lotes de más operaciones que esto (`batch_too_large`).
  static const maxBatch = 500;

  /// Código con el que el servidor rechaza una edición hecha sobre una versión
  /// vieja (D-8).
  static const versionConflict = 'version_conflict';

  final SessionService sessions;
  final PulperiaApi api;
  final AppDatabase db;

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
