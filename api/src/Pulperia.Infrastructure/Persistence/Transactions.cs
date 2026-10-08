using Microsoft.EntityFrameworkCore;

namespace Pulperia.Infrastructure.Persistence;

/// <summary>La transacción atómica que comparten los almacenes de operaciones y de sincronización.</summary>
internal static class Transactions
{
    /// <summary>
    /// Ejecuta el trabajo de forma atómica: si falla, se deshace todo y EF olvida lo que tenía por
    /// guardar. Si ya hay una transacción abierta (la de un lote), el trabajo se une a ella.
    /// </summary>
    public static async Task<T> RunAsync<T>(
        PulperiaDbContext db, Func<Task<T>> work, CancellationToken cancellationToken)
    {
        if (db.Database.CurrentTransaction is not null)
        {
            return await work();
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            var result = await work();
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            // Lo que EF tenía por guardar o ya guardado en esta transacción ya no es verdad.
            db.ChangeTracker.Clear();
            throw;
        }
    }
}
