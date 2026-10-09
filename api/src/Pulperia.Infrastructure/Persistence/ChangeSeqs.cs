using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Sync;

namespace Pulperia.Infrastructure.Persistence;

/// <summary>Consultas sobre <c>change_log</c> que comparten la sincronización y las consultas de lectura.</summary>
internal static class ChangeSeqs
{
    /// <summary>
    /// El <c>seq</c> del primer cambio de cada registro, es decir, cuándo llegó al servidor (D-18).
    /// Para un fiado o abono es el de su creación, aunque se anule después.
    /// </summary>
    public static async Task<Dictionary<Guid, long>> FirstAsync(
        PulperiaDbContext db, ChangeEntityType type, IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken)
    {
        if (ids.Count == 0)
        {
            return [];
        }
        var wanted = ids.ToArray();
        return await db.ChangeLog.AsNoTracking()
            .Where(c => c.EntityType == type && wanted.Contains(c.EntityId))
            .GroupBy(c => c.EntityId)
            .Select(g => new { Id = g.Key, Seq = g.Min(c => c.Seq) })
            .ToDictionaryAsync(x => x.Id, x => x.Seq, cancellationToken);
    }
}
