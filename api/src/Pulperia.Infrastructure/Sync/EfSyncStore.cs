using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Operations;
using Pulperia.Application.Sync;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Sync;
using Pulperia.Infrastructure.Operations;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Sync;

/// <summary>
/// La sincronización sobre EF Core y PostgreSQL. Igual que <c>EfOperationStore</c>, el contexto
/// debe estar limitado a un negocio con <see cref="PulperiaDbContext.WithBusiness"/> (RNF-6).
/// </summary>
public sealed class EfSyncStore : ISyncStore
{
    private readonly PulperiaDbContext _db;
    private readonly Guid _businessId;

    public EfSyncStore(PulperiaDbContext db)
    {
        _db = db;
        _businessId = db.BusinessScope
            ?? throw new ArgumentException("El contexto debe estar limitado a un negocio.", nameof(db));
    }

    public async Task<SyncMembership?> FindMembershipAsync(Guid userId, CancellationToken cancellationToken = default) =>
        await _db.Memberships.AsNoTracking()
            .Where(m => m.UserId == userId && m.BusinessId == _businessId)
            .Select(m => new SyncMembership(m.Role, m.Status, m.FinalSyncUsed))
            .SingleOrDefaultAsync(cancellationToken);

    public async Task<bool> TryClaimFinalSyncAsync(Guid userId, CancellationToken cancellationToken = default) =>
        await _db.Database.ExecuteSqlAsync(
            $"""
            UPDATE memberships SET final_sync_used = true
            WHERE user_id = {userId} AND business_id = {_businessId} AND status = 'removed' AND final_sync_used = false
            """,
            cancellationToken) == 1;

    public async Task LockBusinessAsync(CancellationToken cancellationToken = default) =>
        _ = await _db.Database
            .SqlQuery<int>($"SELECT 1 AS \"Value\" FROM businesses WHERE id = {_businessId} FOR UPDATE")
            .ToListAsync(cancellationToken);

    public async Task<ChangePage> ReadChangesAsync(long cursor, int limit, CancellationToken cancellationToken = default)
    {
        // Una fila de más para saber si queda otra página sin contar.
        var rows = await _db.ChangeLog.AsNoTracking()
            .Where(c => c.Seq > cursor).OrderBy(c => c.Seq).Take(limit + 1)
            .ToListAsync(cancellationToken);
        var hasMore = rows.Count > limit;
        if (hasMore)
        {
            rows.RemoveAt(rows.Count - 1);
        }
        if (rows.Count == 0)
        {
            return new ChangePage(cursor, false, []);
        }

        // Un registro que cambió varias veces en la página viaja una vez, con su último seq.
        var latest = rows
            .GroupBy(r => (r.EntityType, r.EntityId))
            .Select(g => g.Last())
            .OrderBy(r => r.Seq)
            .ToList();
        var records = new Dictionary<(ChangeEntityType, Guid), object>();
        await LoadAsync(latest, ChangeEntityType.Client, ids => LoadClientsAsync(ids, cancellationToken), records);
        await LoadAsync(latest, ChangeEntityType.Product, ids => LoadProductsAsync(ids, cancellationToken), records);
        await LoadAsync(latest, ChangeEntityType.Fiado, ids => LoadFiadosAsync(ids, cancellationToken), records);
        await LoadAsync(latest, ChangeEntityType.Payment, ids => LoadPaymentsAsync(ids, cancellationToken), records);

        // Los movimientos llevan además su orden de llegada, que no es el de su último cambio si se anularon.
        var arrivals = new Dictionary<(ChangeEntityType, Guid), long>();
        foreach (var type in new[] { ChangeEntityType.Fiado, ChangeEntityType.Payment })
        {
            var ids = latest.Where(r => r.EntityType == type).Select(r => r.EntityId).ToArray();
            foreach (var (id, seq) in await ChangeSeqs.FirstAsync(_db, type, ids, cancellationToken))
            {
                arrivals[(type, id)] = seq;
            }
        }

        return new ChangePage(
            rows[^1].Seq,
            hasMore,
            latest.Select(r => new ChangeEntry(
                r.Seq, r.EntityType, records[(r.EntityType, r.EntityId)],
                arrivals.TryGetValue((r.EntityType, r.EntityId), out var arrival) ? arrival : null)).ToList());
    }

    private static async Task LoadAsync(
        List<ChangeLogEntity> changes,
        ChangeEntityType type,
        Func<Guid[], Task<IEnumerable<(Guid Id, object Record)>>> load,
        Dictionary<(ChangeEntityType, Guid), object> into)
    {
        var ids = changes.Where(c => c.EntityType == type).Select(c => c.EntityId).ToArray();
        if (ids.Length == 0)
        {
            return;
        }
        foreach (var (id, record) in await load(ids))
        {
            into[(type, id)] = record;
        }
    }

    private async Task<IEnumerable<(Guid, object)>> LoadClientsAsync(Guid[] ids, CancellationToken cancellationToken) =>
        (await _db.Clients.AsNoTracking().Where(c => ids.Contains(c.Id)).ToListAsync(cancellationToken))
            .Select(c => (c.Id, (object)EfOperationStore.ToRecord(c)));

    private async Task<IEnumerable<(Guid, object)>> LoadProductsAsync(Guid[] ids, CancellationToken cancellationToken) =>
        (await _db.Products.AsNoTracking().Where(p => ids.Contains(p.Id)).ToListAsync(cancellationToken))
            .Select(p => (p.Id, (object)EfOperationStore.ToRecord(p)));

    private async Task<IEnumerable<(Guid, object)>> LoadPaymentsAsync(Guid[] ids, CancellationToken cancellationToken) =>
        (await _db.Payments.AsNoTracking().Where(p => ids.Contains(p.Id)).ToListAsync(cancellationToken))
            .Select(p => (p.Id, (object)EfOperationStore.ToRecord(p)));

    private async Task<IEnumerable<(Guid, object)>> LoadFiadosAsync(Guid[] ids, CancellationToken cancellationToken)
    {
        var fiados = await _db.Fiados.AsNoTracking().Where(f => ids.Contains(f.Id)).ToListAsync(cancellationToken);
        var items = (await _db.FiadoItems.AsNoTracking().Where(i => ids.Contains(i.FiadoId)).OrderBy(i => i.Id)
                .ToListAsync(cancellationToken))
            .ToLookup(i => i.FiadoId);
        return fiados.Select(f => (f.Id, (object)new FiadoRecord(
            f.Id, f.ClientId, new Money(f.Total), f.OccurredAt, f.CreatedBy, f.AnnulledAt, f.AnnulledBy,
            items[f.Id].Select(EfOperationStore.ToRecord).ToList())));
    }

    public async Task<ProcessedOp?> FindProcessedOpAsync(Guid opId, CancellationToken cancellationToken = default)
    {
        // Sin el filtro del negocio: el op_id es único en toda la tabla y reutilizarlo desde otro
        // negocio chocaría al guardar. Solo se devuelve si fue aquí; de otro negocio no se lee nada más.
        var row = await _db.ProcessedOps.IgnoreQueryFilters().AsNoTracking()
            .Where(o => o.OpId == opId)
            .Select(o => new { o.Result, o.BusinessId })
            .SingleOrDefaultAsync(cancellationToken);
        return row is null ? null : new ProcessedOp(row.Result, row.BusinessId == _businessId);
    }

    public async Task AddProcessedOpAsync(
        Guid opId, string result, DateTime processedAt, CancellationToken cancellationToken = default)
    {
        _db.ProcessedOps.Add(new ProcessedOpEntity
        {
            OpId = opId, BusinessId = _businessId, Result = result, ProcessedAt = processedAt,
        });
        await _db.SaveChangesAsync(cancellationToken);
    }

    public Task<T> InTransactionAsync<T>(Func<Task<T>> work, CancellationToken cancellationToken = default) =>
        Transactions.RunAsync(_db, work, cancellationToken);
}
