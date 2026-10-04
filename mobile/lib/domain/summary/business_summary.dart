import '../ledger/balance.dart';
import '../money/money.dart';

/// Saldo de un cliente tal como entra al resumen del negocio.
final class ClientBalance {
  const ClientBalance({
    required this.id,
    required this.balance,
    required this.archived,
  });

  final String id;
  final Balance balance;
  final bool archived;
}

/// Un cliente con deuda en la lista de mayores deudores.
final class DebtorEntry {
  const DebtorEntry({required this.clientId, required this.debt});

  final String clientId;

  /// Lo que debe, siempre positivo.
  final Money debt;
}

final class BusinessSummary {
  const BusinessSummary({
    required this.debtTotal,
    required this.creditTotal,
    required this.debtors,
  });

  /// Suma de los saldos positivos de los clientes no archivados (RF-63).
  final Money debtTotal;

  /// Suma del saldo a favor de los clientes no archivados, aparte y sin
  /// restar de la deuda (RF-64).
  final Money creditTotal;

  /// Clientes no archivados con deuda, de mayor a menor (RF-65). Los empates
  /// se desempatan por id ascendente (comparación ordinal del texto).
  final List<DebtorEntry> debtors;
}

/// Calcula el resumen del negocio a partir del saldo de cada cliente. Los
/// archivados no cuentan; los saldados no aparecen en la lista. La lista es
/// completa: cuántos mostrar lo decide la interfaz.
BusinessSummary summarize(Iterable<ClientBalance> clients) {
  var debtTotal = Money.zero;
  var creditTotal = Money.zero;
  final debtors = <DebtorEntry>[];

  for (final client in clients) {
    if (client.archived) {
      continue;
    }
    debtTotal += client.balance.debt;
    creditTotal += client.balance.credit;
    if (client.balance.debt.isPositive) {
      debtors.add(DebtorEntry(clientId: client.id, debt: client.balance.debt));
    }
  }

  debtors.sort((a, b) {
    final byDebt = b.debt.compareTo(a.debt);
    return byDebt != 0 ? byDebt : a.clientId.compareTo(b.clientId);
  });

  return BusinessSummary(
    debtTotal: debtTotal,
    creditTotal: creditTotal,
    debtors: List.unmodifiable(debtors),
  );
}
