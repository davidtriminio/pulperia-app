using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Sync;
using Pulperia.Infrastructure.Persistence;

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

    public Task<T> InTransactionAsync<T>(Func<Task<T>> work, CancellationToken cancellationToken = default) =>
        Transactions.RunAsync(_db, work, cancellationToken);
}
