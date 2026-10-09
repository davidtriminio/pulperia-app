using Pulperia.Application.Operations;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;
using Pulperia.Domain.Summary;

namespace Pulperia.Application.Queries;

/// <summary>
/// Las consultas de lectura de la web (plan 5): el saldo y el resumen se calculan siempre con las
/// reglas del dominio, nunca se guardan (D-6).
/// </summary>
public sealed class QueryService(IQueryStore store)
{
    /// <summary>Clientes archivados o no, con su saldo, por nombre sin distinguir mayúsculas (RF-22).</summary>
    public async Task<IReadOnlyList<ClientWithBalance>> ListClientsAsync(
        bool archived, CancellationToken cancellationToken = default) =>
        (await store.ListClientTotalsAsync(archived, cancellationToken))
            .Select(t => new ClientWithBalance(t.Client, BalanceOf(t)))
            .OrderBy(c => c.Client.Name, StringComparer.InvariantCultureIgnoreCase)
            .ThenBy(c => c.Client.Id.ToString(), StringComparer.Ordinal)
            .ToList();

    /// <summary>
    /// El cliente con su saldo y su historial (RF-41). Los movimientos van del más antiguo al más
    /// reciente: por la fecha de creación en el dispositivo, luego por llegada al servidor y al
    /// final por id (D-18, igual que el móvil).
    /// </summary>
    public async Task<ClientHistory?> GetClientAsync(Guid clientId, CancellationToken cancellationToken = default)
    {
        if (await store.FindClientMovementsAsync(clientId, cancellationToken) is not { } data)
        {
            return null;
        }

        var entries = data.Fiados
            .Select(f => new HistoryEntry(
                MovementKind.Fiado, f.Fiado.Id, f.Fiado.Total, f.Fiado.OccurredAt, f.ServerSeq, f.Fiado.CreatedBy,
                f.Fiado.AnnulledAt, f.Fiado.AnnulledBy, f.Fiado.Items))
            .Concat(data.Payments.Select(p => new HistoryEntry(
                MovementKind.Payment, p.Payment.Id, p.Payment.Amount, p.Payment.OccurredAt, p.ServerSeq, p.Payment.CreatedBy,
                p.Payment.AnnulledAt, p.Payment.AnnulledBy, [])))
            .OrderBy(e => e.OccurredAt)
            .ThenBy(e => e.ServerSeq)
            .ThenBy(e => e.Id.ToString(), StringComparer.Ordinal)
            .ToList();
        var balance = Balances.Compute(entries.Select(e => new LedgerMovement(e.Kind, e.Amount, e.AnnulledAt is not null)));
        return new ClientHistory(data.Client, balance, entries);
    }

    public async Task<IReadOnlyList<ProductRecord>> ListProductsAsync(
        bool archived, CancellationToken cancellationToken = default) =>
        (await store.ListProductsAsync(archived, cancellationToken))
            .OrderBy(p => p.Name, StringComparer.InvariantCultureIgnoreCase)
            .ThenBy(p => p.Id.ToString(), StringComparer.Ordinal)
            .ToList();

    private static Balance BalanceOf(ClientTotals totals) => Balances.Compute(
    [
        new LedgerMovement(MovementKind.Fiado, totals.FiadoTotal, Annulled: false),
        new LedgerMovement(MovementKind.Payment, totals.PaymentTotal, Annulled: false),
    ]);
}
