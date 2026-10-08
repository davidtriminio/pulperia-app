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
}
