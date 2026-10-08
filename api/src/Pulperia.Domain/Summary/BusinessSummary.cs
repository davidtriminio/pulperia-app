using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;

namespace Pulperia.Domain.Summary;

/// <summary>Saldo de un cliente tal como entra al resumen del negocio.</summary>
public sealed record ClientBalance(string Id, Balance Balance, bool Archived);

/// <summary>Un cliente con deuda en la lista de mayores deudores.</summary>
/// <param name="Debt">Lo que debe, siempre positivo.</param>
public sealed record DebtorEntry(string ClientId, Money Debt);

/// <param name="DebtTotal">Suma de los saldos positivos de los clientes no archivados (RF-63).</param>
/// <param name="CreditTotal">Saldo a favor total de los no archivados, aparte y sin restar de la deuda (RF-64).</param>
/// <param name="Debtors">
/// Clientes no archivados con deuda, de mayor a menor (RF-65). Los empates se desempatan por
/// id ascendente (comparación ordinal del texto).
/// </param>
public sealed record BusinessSummary(Money DebtTotal, Money CreditTotal, IReadOnlyList<DebtorEntry> Debtors);

public static class Summaries
{
    /// <summary>
    /// Calcula el resumen del negocio a partir del saldo de cada cliente. Los archivados no
    /// cuentan; los saldados no aparecen en la lista. La lista es completa: cuántos mostrar
    /// lo decide la interfaz.
    /// </summary>
    public static BusinessSummary Summarize(IEnumerable<ClientBalance> clients)
    {
        var debtTotal = Money.Zero;
        var creditTotal = Money.Zero;
        var debtors = new List<DebtorEntry>();

        foreach (var client in clients)
        {
            if (client.Archived)
            {
                continue;
            }
            debtTotal += client.Balance.Debt;
            creditTotal += client.Balance.Credit;
            if (client.Balance.Debt.IsPositive)
            {
                debtors.Add(new DebtorEntry(client.Id, client.Balance.Debt));
            }
        }

        debtors.Sort((a, b) =>
        {
            var byDebt = b.Debt.CompareTo(a.Debt);
            return byDebt != 0 ? byDebt : string.CompareOrdinal(a.ClientId, b.ClientId);
        });

        return new BusinessSummary(debtTotal, creditTotal, debtors);
    }
}
