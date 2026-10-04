import '../money/money.dart';

enum MovementKind { fiado, payment }

/// Un movimiento del historial de un cliente, tal como cuenta para su saldo.
final class LedgerMovement {
  const LedgerMovement({
    required this.kind,
    required this.amount,
    required this.annulled,
  });

  final MovementKind kind;
  final Money amount;

  /// Los movimientos anulados se conservan en el historial pero no cuentan
  /// para el saldo (RF-44).
  final bool annulled;
}

enum BalanceLabel {
  debt('debt'),
  credit('credit'),
  settled('settled');

  const BalanceLabel(this.id);

  /// Identificador estable, el mismo de los vectores compartidos.
  final String id;
}

/// Saldo de un cliente: positivo es deuda, negativo es saldo a favor (RF-42).
final class Balance {
  const Balance(this.amount);

  final Money amount;

  BalanceLabel get label {
    if (amount.isPositive) {
      return BalanceLabel.debt;
    }
    if (amount.isNegative) {
      return BalanceLabel.credit;
    }
    return BalanceLabel.settled;
  }

  /// Lo que el cliente debe, siempre positivo o cero.
  Money get debt => amount.isPositive ? amount : Money.zero;

  /// Lo que el cliente tiene a favor, siempre positivo o cero.
  Money get credit => amount.isNegative ? -amount : Money.zero;

  @override
  bool operator ==(Object other) => other is Balance && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;

  @override
  String toString() => 'Balance($amount)';
}

/// Saldo = suma de los fiados vigentes menos suma de los abonos vigentes
/// (RF-40). Un abono mayor que la deuda deja saldo a favor (RF-39), y los
/// abonos se conservan aunque el fiado se haya anulado en otro dispositivo
/// (RF-47). No guarda nada: se calcula siempre desde los movimientos.
Balance computeBalance(Iterable<LedgerMovement> movements) {
  var total = Money.zero;
  for (final movement in movements) {
    if (movement.annulled) {
      continue;
    }
    total = switch (movement.kind) {
      MovementKind.fiado => total + movement.amount,
      MovementKind.payment => total - movement.amount,
    };
  }
  return Balance(total);
}
