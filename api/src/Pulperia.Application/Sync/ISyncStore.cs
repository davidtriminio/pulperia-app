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
    /// Ejecuta el trabajo de forma atómica; si falla, se deshace todo. Si ya hay una transacción
    /// abierta, el trabajo se une a ella.
    /// </summary>
    Task<T> InTransactionAsync<T>(Func<Task<T>> work, CancellationToken cancellationToken = default);
}
