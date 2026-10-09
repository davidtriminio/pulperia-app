using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Operations;
using Pulperia.Application.Queries;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Sync;
using Pulperia.Infrastructure.Operations;
using Pulperia.Infrastructure.Persistence;

namespace Pulperia.Infrastructure.Queries;

/// <summary>
/// Las consultas de lectura sobre EF Core y PostgreSQL. El contexto debe estar limitado a un
/// negocio con <see cref="PulperiaDbContext.WithBusiness"/> (RNF-6).
/// </summary>
public sealed class EfQueryStore : IQueryStore
{
    private readonly PulperiaDbContext _db;

    public EfQueryStore(PulperiaDbContext db)
    {
        _db = db;
        _ = db.BusinessScope ?? throw new ArgumentException("El contexto debe estar limitado a un negocio.", nameof(db));
    }

    public async Task<IReadOnlyList<ClientTotals>> ListClientTotalsAsync(bool? archived, CancellationToken cancellationToken = default)
    {
        var query = _db.Clients.AsNoTracking();
        if (archived is { } wanted)
        {
            query = query.Where(c => c.Archived == wanted);
        }
        var clients = await query.ToListAsync(cancellationToken);

        // Suma en la base solo de lo vigente; el saldo lo decide el dominio con estas dos sumas.
        var fiados = await _db.Fiados.AsNoTracking().Where(f => f.AnnulledAt == null)
            .GroupBy(f => f.ClientId).Select(g => new { g.Key, Total = g.Sum(f => f.Total) })
            .ToDictionaryAsync(x => x.Key, x => x.Total, cancellationToken);
        var payments = await _db.Payments.AsNoTracking().Where(p => p.AnnulledAt == null)
            .GroupBy(p => p.ClientId).Select(g => new { g.Key, Total = g.Sum(p => p.Amount) })
            .ToDictionaryAsync(x => x.Key, x => x.Total, cancellationToken);

        return clients
            .Select(c => new ClientTotals(
                EfOperationStore.ToRecord(c),
                new Money(fiados.GetValueOrDefault(c.Id)),
                new Money(payments.GetValueOrDefault(c.Id))))
            .ToList();
    }

    public async Task<ClientMovements?> FindClientMovementsAsync(Guid clientId, CancellationToken cancellationToken = default)
    {
        var client = await _db.Clients.AsNoTracking().SingleOrDefaultAsync(c => c.Id == clientId, cancellationToken);
        if (client is null)
        {
            return null;
        }

        var fiados = await _db.Fiados.AsNoTracking().Where(f => f.ClientId == clientId).ToListAsync(cancellationToken);
        var payments = await _db.Payments.AsNoTracking().Where(p => p.ClientId == clientId).ToListAsync(cancellationToken);
        var fiadoIds = fiados.Select(f => f.Id).ToArray();
        var items = (await _db.FiadoItems.AsNoTracking().Where(i => fiadoIds.Contains(i.FiadoId)).OrderBy(i => i.Id)
                .ToListAsync(cancellationToken))
            .ToLookup(i => i.FiadoId);
        var fiadoSeqs = await ChangeSeqs.FirstAsync(_db, ChangeEntityType.Fiado, fiadoIds, cancellationToken);
        var paymentSeqs = await ChangeSeqs.FirstAsync(_db, ChangeEntityType.Payment, payments.Select(p => p.Id).ToArray(), cancellationToken);

        return new ClientMovements(
            EfOperationStore.ToRecord(client),
            fiados.Select(f => new FiadoArrival(
                new FiadoRecord(
                    f.Id, f.ClientId, new Money(f.Total), f.OccurredAt, f.CreatedBy, f.AnnulledAt, f.AnnulledBy,
                    items[f.Id].Select(EfOperationStore.ToRecord).ToList()),
                fiadoSeqs.GetValueOrDefault(f.Id))).ToList(),
            payments.Select(p => new PaymentArrival(EfOperationStore.ToRecord(p), paymentSeqs.GetValueOrDefault(p.Id))).ToList());
    }

    public async Task<IReadOnlyList<ProductRecord>> ListProductsAsync(bool archived, CancellationToken cancellationToken = default) =>
        (await _db.Products.AsNoTracking().Where(p => p.Archived == archived).ToListAsync(cancellationToken))
            .Select(EfOperationStore.ToRecord)
            .ToList();
}
