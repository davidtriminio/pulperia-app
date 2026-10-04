import '../../domain/ledger/balance.dart';
import '../../domain/money/money.dart';
import '../../domain/summary/business_summary.dart';
import '../local/app_database.dart';
import 'ledger_queries.dart';

/// Consulta de solo lectura del resumen del negocio.
class SummaryQueries {
  SummaryQueries(this._db);

  final AppDatabase _db;

  /// Resumen del negocio calculado solo con los datos locales (RF-66): deuda
  /// total, saldo a favor total y mayores deudores, sin los clientes
  /// archivados (RF-63, RF-64, RF-65).
  ///
  /// Lee la base del dispositivo, donde cada cambio queda guardado antes de
  /// sincronizarse, así que incluye lo que aún falta por enviar al servidor y
  /// funciona sin conexión.
  Future<BusinessSummary> summaryOf(String businessId) async {
    final clients = await (_db.select(
      _db.clients,
    )..where((c) => c.businessId.equals(businessId))).get();
    final balances = await LedgerQueries(_db).balancesByClient(businessId);

    return summarize([
      for (final c in clients)
        ClientBalance(
          id: c.id,
          balance: balances[c.id] ?? const Balance(Money.zero),
          archived: c.archived,
        ),
    ]);
  }
}
