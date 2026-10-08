namespace Pulperia.Application.Sync;

/// <summary>
/// Lo que la sincronización necesita de la base de datos además de lo del aplicador de
/// operaciones. Una instancia está limitada a un negocio (RNF-6) y comparte contexto, y por tanto
/// transacción, con el <c>IOperationStore</c> que se use con ella.
/// </summary>
public interface ISyncStore
{
    /// <summary>La pertenencia del usuario a este negocio, activa o removida; null si nunca perteneció.</summary>
    Task<SyncMembership?> FindMembershipAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Bloquea el negocio hasta que termine la transacción: dos lotes del mismo negocio se esperan
    /// y los <c>seq</c> salen en orden y sin huecos (D-5). Debe llamarse dentro de
    /// <see cref="InTransactionAsync"/>.
    /// </summary>
    Task LockBusinessAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// La operación ya procesada con ese <c>op_id</c>, en este negocio o en otro (el identificador es
    /// único en toda la tabla); null si es nueva.
    /// </summary>
    Task<ProcessedOp?> FindProcessedOpAsync(Guid opId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Hasta <paramref name="limit"/> registros que cambiaron después de <paramref name="cursor"/>, en
    /// orden de <c>seq</c>, cada uno con su versión actual. Un registro que cambió varias veces
    /// dentro de la página viaja una sola vez.
    /// </summary>
    Task<ChangePage> ReadChangesAsync(long cursor, int limit, CancellationToken cancellationToken = default);

    /// <summary>Deja constancia de que la operación se procesó, para no repetirla (RF-53).</summary>
    Task AddProcessedOpAsync(Guid opId, string result, DateTime processedAt, CancellationToken cancellationToken = default);

    /// <summary>
    /// Ejecuta el trabajo de forma atómica; si falla, se deshace todo. Si ya hay una transacción
    /// abierta, el trabajo se une a ella.
    /// </summary>
    Task<T> InTransactionAsync<T>(Func<Task<T>> work, CancellationToken cancellationToken = default);
}
