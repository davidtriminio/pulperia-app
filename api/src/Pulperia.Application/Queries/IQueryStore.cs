using Pulperia.Application.Operations;

namespace Pulperia.Application.Queries;

/// <summary>
/// Lo que las consultas de lectura necesitan de la base de datos. Una instancia está limitada a
/// un negocio (RNF-6), así que ninguna búsqueda devuelve datos de otro.
/// </summary>
public interface IQueryStore
{
    /// <summary>Los clientes (todos, o solo archivados / no archivados) con sus totales vigentes.</summary>
    Task<IReadOnlyList<ClientTotals>> ListClientTotalsAsync(bool? archived, CancellationToken cancellationToken = default);

    /// <summary>El cliente con todos sus fiados (con ítems) y abonos; null si no existe en el negocio.</summary>
    Task<ClientMovements?> FindClientMovementsAsync(Guid clientId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ProductRecord>> ListProductsAsync(bool archived, CancellationToken cancellationToken = default);
}
