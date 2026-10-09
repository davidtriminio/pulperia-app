import 'dart:convert';

import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../remote/api_client.dart';
import '../remote/models.dart';
import '../session/session_service.dart';

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

  Future<List<OutboxOp>> _nextBatch(String businessId) =>
      (db.select(db.outboxOps)
            ..where(
              (o) =>
                  o.businessId.equals(businessId) & o.status.equals('pending'),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.localSeq)])
            ..limit(maxBatch))
          .get();

  PushOperation _toPush(OutboxOp op) => PushOperation(
    opId: op.opId,
    type: op.type,
    entityId: op.entityId,
    payload: jsonDecode(op.payload) as Map<String, dynamic>,
    baseVersion: op.baseVersion,
    createdAt: op.createdAt,
  );
}
