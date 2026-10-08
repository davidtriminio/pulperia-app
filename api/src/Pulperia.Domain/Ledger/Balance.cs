using Pulperia.Domain.Amounts;

namespace Pulperia.Domain.Ledger;

public enum MovementKind
{
    Fiado,
    Payment,
}

/// <summary>Un movimiento del historial de un cliente, tal como cuenta para su saldo.</summary>
/// <param name="Annulled">
/// Los movimientos anulados se conservan en el historial pero no cuentan para el saldo (RF-44).
/// </param>
public readonly record struct LedgerMovement(MovementKind Kind, Money Amount, bool Annulled);

public enum BalanceLabel
{
    Debt,
    Credit,
    Settled,
}

public static class BalanceLabels
{
    /// <summary>Identificador estable, el mismo de los vectores compartidos.</summary>
    public static string Id(this BalanceLabel label) => label switch
    {
        BalanceLabel.Debt => "debt",
        BalanceLabel.Credit => "credit",
        BalanceLabel.Settled => "settled",
        _ => throw new ArgumentOutOfRangeException(nameof(label)),
    };
}

/// <summary>Saldo de un cliente: positivo es deuda, negativo es saldo a favor (RF-42).</summary>
public readonly record struct Balance(Money Amount)
{
    public BalanceLabel Label =>
        Amount.IsPositive ? BalanceLabel.Debt
        : Amount.IsNegative ? BalanceLabel.Credit
        : BalanceLabel.Settled;

    /// <summary>Lo que el cliente debe, siempre positivo o cero.</summary>
    public Money Debt => Amount.IsPositive ? Amount : Money.Zero;

    /// <summary>Lo que el cliente tiene a favor, siempre positivo o cero.</summary>
    public Money Credit => Amount.IsNegative ? -Amount : Money.Zero;
}

public static class Balances
{
    /// <summary>
    /// Saldo = suma de los fiados vigentes menos suma de los abonos vigentes (RF-40). Un
    /// abono mayor que la deuda deja saldo a favor (RF-39), y los abonos se conservan
    /// aunque el fiado se haya anulado en otro dispositivo (RF-47). No guarda nada: se
    /// calcula siempre desde los movimientos.
    /// </summary>
    public static Balance Compute(IEnumerable<LedgerMovement> movements)
    {
        var total = Money.Zero;
        foreach (var movement in movements)
        {
            if (movement.Annulled)
            {
                continue;
            }
            total = movement.Kind switch
            {
                MovementKind.Fiado => total + movement.Amount,
                MovementKind.Payment => total - movement.Amount,
                _ => throw new ArgumentOutOfRangeException(nameof(movements)),
            };
        }
        return new Balance(total);
    }
}
