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
}
