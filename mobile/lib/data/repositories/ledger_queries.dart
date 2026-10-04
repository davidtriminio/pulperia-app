import 'package:drift/drift.dart';

import '../../domain/ledger/balance.dart';
import '../../domain/ledger/history_order.dart';
import '../../domain/money/money.dart';
import '../local/app_database.dart';

/// Un movimiento del historial de un cliente: un fiado o un abono.
final class HistoryEntry implements HistoryPosition {
  const HistoryEntry({
    required this.kind,
    required this.id,
    required this.amount,
    required this.occurredAt,
    required this.serverSeq,
    required this.createdBy,
    required this.annulledAt,
    required this.annulledBy,
    required this.items,
  });

  final MovementKind kind;
  @override
  final String id;
  final Money amount;
  @override
  final DateTime occurredAt;
  @override
  final int? serverSeq;
  final String createdBy;

  /// Un movimiento anulado se conserva en el historial con su marca (RF-41),
  /// pero no cuenta en el saldo (RF-44).
  final DateTime? annulledAt;
  final String? annulledBy;

  /// Detalle del fiado; vacío en un abono y en un fiado solo con total.
  final List<FiadoItem> items;

  bool get isAnnulled => annulledAt != null;
}

/// Un cliente con su saldo y su historial.
final class ClientHistory {
  const ClientHistory({
    required this.client,
    required this.balance,
    required this.entries,
  });

  final Client client;
  final Balance balance;

  /// Del movimiento más antiguo al más reciente (RF-41, D-18).
  final List<HistoryEntry> entries;
}

/// Consultas de lectura sobre los movimientos: saldo e historial. No escriben
/// nada.
class LedgerQueries {
  LedgerQueries(this._db);

  final AppDatabase _db;

  /// Saldo de un cliente (RF-40, RF-42); null si el cliente no existe en el
  /// negocio.
  Future<Balance?> balanceOf(String businessId, String clientId) async =>
      (await historyOf(businessId, clientId))?.balance;

  /// Historial cronológico de un cliente, con el detalle de ítems de cada
  /// fiado y con los movimientos anulados marcados (RF-41); null si el
  /// cliente no existe en el negocio. Sirve también para un cliente
  /// archivado.
  Future<ClientHistory?> historyOf(String businessId, String clientId) async {
    final client =
        await (_db.select(_db.clients)..where(
              (c) => c.id.equals(clientId) & c.businessId.equals(businessId),
            ))
            .getSingleOrNull();
    if (client == null) {
      return null;
    }

    final fiados =
        await (_db.select(_db.fiados)..where(
              (f) =>
                  f.businessId.equals(businessId) & f.clientId.equals(clientId),
            ))
            .get();
    final payments =
        await (_db.select(_db.payments)..where(
              (p) =>
                  p.businessId.equals(businessId) & p.clientId.equals(clientId),
            ))
            .get();

    final itemsByFiado = <String, List<FiadoItem>>{};
    if (fiados.isNotEmpty) {
      final items =
          await (_db.select(_db.fiadoItems)
                ..where(
                  (i) =>
                      i.businessId.equals(businessId) &
                      i.fiadoId.isIn([for (final f in fiados) f.id]),
                )
                ..orderBy([(i) => OrderingTerm.asc(i.rowId)]))
              .get();
      for (final item in items) {
        itemsByFiado.putIfAbsent(item.fiadoId, () => []).add(item);
      }
    }

    final entries = sortHistory([
      for (final f in fiados)
        HistoryEntry(
          kind: MovementKind.fiado,
          id: f.id,
          amount: Money(f.total),
          occurredAt: f.occurredAt,
          serverSeq: f.serverSeq,
          createdBy: f.createdBy,
          annulledAt: f.annulledAt,
          annulledBy: f.annulledBy,
          items: itemsByFiado[f.id] ?? const [],
        ),
      for (final p in payments)
        HistoryEntry(
          kind: MovementKind.payment,
          id: p.id,
          amount: Money(p.amount),
          occurredAt: p.occurredAt,
          serverSeq: p.serverSeq,
          createdBy: p.createdBy,
          annulledAt: p.annulledAt,
          annulledBy: p.annulledBy,
          items: const [],
        ),
    ]);

    return ClientHistory(
      client: client,
      balance: computeBalance([
        for (final e in entries)
          LedgerMovement(
            kind: e.kind,
            amount: e.amount,
            annulled: e.isAnnulled,
          ),
      ]),
      entries: entries,
    );
  }

  /// Saldo de cada cliente del negocio que tiene movimientos. Un cliente que
  /// no aparece aquí no tiene movimientos: está saldado.
  Future<Map<String, Balance>> balancesByClient(String businessId) async {
    final movements = <String, List<LedgerMovement>>{};

    final fiados = await (_db.select(
      _db.fiados,
    )..where((f) => f.businessId.equals(businessId))).get();
    for (final f in fiados) {
      movements
          .putIfAbsent(f.clientId, () => [])
          .add(
            LedgerMovement(
              kind: MovementKind.fiado,
              amount: Money(f.total),
              annulled: f.annulledAt != null,
            ),
          );
    }
    final payments = await (_db.select(
      _db.payments,
    )..where((p) => p.businessId.equals(businessId))).get();
    for (final p in payments) {
      movements
          .putIfAbsent(p.clientId, () => [])
          .add(
            LedgerMovement(
              kind: MovementKind.payment,
              amount: Money(p.amount),
              annulled: p.annulledAt != null,
            ),
          );
    }

    return {
      for (final entry in movements.entries)
        entry.key: computeBalance(entry.value),
    };
  }
}
