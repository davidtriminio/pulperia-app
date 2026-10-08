using Pulperia.Domain.Sync;

namespace Pulperia.Application.Operations;

/// <summary>
/// Lo que el aplicador de operaciones necesita de la base de datos. La capa de aplicación no
/// conoce EF Core (principio 7): Infrastructure lo implementa. Una instancia está limitada a un
/// negocio, así que ninguna búsqueda devuelve datos de otro (RNF-6).
/// </summary>
public interface IOperationStore
{
    Task<ClientRecord?> FindClientAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddClientAsync(ClientRecord client, CancellationToken cancellationToken = default);

    /// <summary>Reemplaza los datos del cliente que tiene ese id.</summary>
    Task UpdateClientAsync(ClientRecord client, CancellationToken cancellationToken = default);

    /// <summary>Los modos de montos y cantidades vigentes del negocio de esta instancia.</summary>
    Task<BusinessModes> GetModesAsync(CancellationToken cancellationToken = default);

    Task<ProductRecord?> FindProductAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddProductAsync(ProductRecord product, CancellationToken cancellationToken = default);

    /// <summary>Reemplaza los datos del producto que tiene ese id. No hay forma de borrar uno (RF-27).</summary>
    Task UpdateProductAsync(ProductRecord product, CancellationToken cancellationToken = default);

    Task<FiadoRecord?> FindFiadoAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Cuáles de estos ids de ítem ya existen en algún fiado del negocio.</summary>
    Task<IReadOnlySet<Guid>> FindExistingItemIdsAsync(
        IReadOnlyCollection<Guid> itemIds, CancellationToken cancellationToken = default);

    /// <summary>Guarda el fiado con todos sus ítems en un solo guardado.</summary>
    Task AddFiadoAsync(FiadoRecord fiado, CancellationToken cancellationToken = default);

    Task<PaymentRecord?> FindPaymentAsync(Guid id, CancellationToken cancellationToken = default);

    Task AddPaymentAsync(PaymentRecord payment, CancellationToken cancellationToken = default);

    /// <summary>Marca el fiado como anulado, con la fecha y el usuario. No toca nada más (RF-46).</summary>
    Task AnnulFiadoAsync(Guid id, DateTime at, Guid by, CancellationToken cancellationToken = default);

    /// <summary>Marca el abono como anulado, con la fecha y el usuario. No toca nada más (RF-46).</summary>
    Task AnnulPaymentAsync(Guid id, DateTime at, Guid by, CancellationToken cancellationToken = default);

    /// <summary>
    /// Reserva el siguiente <c>seq</c> del negocio y escribe la fila de <c>change_log</c> de esa
    /// entidad. Debe llamarse dentro de <see cref="InTransactionAsync"/>, con la entidad ya guardada.
    /// </summary>
    Task RecordChangeAsync(ChangeEntityType type, Guid entityId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Ejecuta el trabajo de forma atómica: si falla, se deshace todo, también el contador del
    /// <c>seq</c>, así que no quedan huecos ni entidades sin registro (T062). Si ya hay una
    /// transacción abierta (la de un lote), el trabajo se une a ella.
    /// </summary>
    Task<T> InTransactionAsync<T>(Func<Task<T>> work, CancellationToken cancellationToken = default);
}
