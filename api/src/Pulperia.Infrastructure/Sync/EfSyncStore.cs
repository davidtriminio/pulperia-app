using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Sync;
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

    public async Task LockBusinessAsync(CancellationToken cancellationToken = default) =>
        _ = await _db.Database
            .SqlQuery<int>($"SELECT 1 AS \"Value\" FROM businesses WHERE id = {_businessId} FOR UPDATE")
            .ToListAsync(cancellationToken);

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
