namespace Pulperia.Application.Management;

/// <summary>
/// Lo que la gestión del negocio (ajustes, invitaciones y equipo) necesita de la base de datos.
/// Son operaciones en línea, fuera de la cola de sincronización (D-3).
/// </summary>
public interface IManagementStore
{
    Task<BusinessSettings?> GetSettingsAsync(Guid businessId, CancellationToken cancellationToken = default);

    Task UpdateSettingsAsync(Guid businessId, BusinessSettings settings, CancellationToken cancellationToken = default);
}
