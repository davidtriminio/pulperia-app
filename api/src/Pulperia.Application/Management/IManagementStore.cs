using Pulperia.Domain.Invitations;

namespace Pulperia.Application.Management;

/// <summary>
/// Lo que la gestión del negocio (ajustes, invitaciones y equipo) necesita de la base de datos.
/// Son operaciones en línea, fuera de la cola de sincronización (D-3).
/// </summary>
public interface IManagementStore
{
    Task<BusinessSettings?> GetSettingsAsync(Guid businessId, CancellationToken cancellationToken = default);

    Task UpdateSettingsAsync(Guid businessId, BusinessSettings settings, CancellationToken cancellationToken = default);

    Task<string?> FindUserEmailAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Si el correo pertenece a un usuario con pertenencia activa en el negocio.</summary>
    Task<bool> IsActiveMemberByEmailAsync(Guid businessId, string normalizedEmail, CancellationToken cancellationToken = default);

    Task<bool> HasPendingInvitationAsync(Guid businessId, string normalizedEmail, CancellationToken cancellationToken = default);

    Task AddInvitationAsync(
        Invitation invitation, Guid createdBy, DateTime createdAt, CancellationToken cancellationToken = default);

    Task<Invitation?> FindInvitationAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Las invitaciones pendientes de un correo, con el nombre del negocio (RF-67).</summary>
    Task<IReadOnlyList<InvitationOffer>> ListPendingInvitationsAsync(
        string normalizedEmail, CancellationToken cancellationToken = default);

    /// <summary>
    /// Pasa la invitación de pendiente a aceptada y deja al usuario como empleado activo del
    /// negocio (si estaba removido, se reactiva), todo en una transacción. Devuelve false, sin
    /// cambiar nada, si la invitación ya no estaba pendiente: de dos aceptaciones simultáneas
    /// solo una gana.
    /// </summary>
    Task<bool> AcceptInvitationAsync(Guid invitationId, Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Pasa la invitación de pendiente a rechazada; false si ya no estaba pendiente.</summary>
    Task<bool> RejectInvitationAsync(Guid invitationId, CancellationToken cancellationToken = default);
}
