using Pulperia.Domain.Invitations;
using Pulperia.Domain.Team;

namespace Pulperia.Application.Management;

/// <summary>
/// Lo que la gestión del negocio (ajustes, invitaciones y equipo) necesita de la base de datos.
/// Son operaciones en línea, fuera de la cola de sincronización (D-3).
/// </summary>
public interface IManagementStore
{
    Task<BusinessSettings?> GetSettingsAsync(Guid businessId, CancellationToken cancellationToken = default);

    /// <summary>El estado del negocio (D-30); <c>Active</c> si no se encuentra.</summary>
    Task<Pulperia.Domain.Business.BusinessStatus> GetStatusAsync(Guid businessId, CancellationToken cancellationToken = default);

    Task UpdateSettingsAsync(Guid businessId, BusinessSettings settings, CancellationToken cancellationToken = default);

    Task<string?> FindUserEmailAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Si el correo pertenece a un usuario con pertenencia activa en el negocio.</summary>
    Task<bool> IsActiveMemberByEmailAsync(Guid businessId, string normalizedEmail, CancellationToken cancellationToken = default);

    Task<bool> HasPendingInvitationAsync(Guid businessId, string normalizedEmail, CancellationToken cancellationToken = default);

    /// <summary>Guarda la invitación; false, sin guardar nada, si su código ya existe (para generar otro).</summary>
    Task<bool> TryAddInvitationAsync(
        Invitation invitation, Guid createdBy, DateTime createdAt, CancellationToken cancellationToken = default);

    /// <summary>La invitación pendiente que tiene ese código normalizado, o null.</summary>
    Task<Invitation?> FindPendingInvitationByCodeAsync(string code, CancellationToken cancellationToken = default);

    Task<bool> IsActiveMemberAsync(Guid userId, Guid businessId, CancellationToken cancellationToken = default);

    Task<Invitation?> FindInvitationAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Las invitaciones pendientes de un correo, con el nombre del negocio (RF-67).</summary>
    Task<IReadOnlyList<InvitationOffer>> ListPendingInvitationsAsync(
        string normalizedEmail, CancellationToken cancellationToken = default);

    /// <summary>
    /// Pasa la invitación de pendiente a aceptada y deja al usuario como empleado activo del
    /// negocio (si estaba removido, se reactiva; si ya era miembro activo, conserva su rol),
    /// todo en una transacción. Devuelve false, sin
    /// cambiar nada, si la invitación ya no estaba pendiente: de dos aceptaciones simultáneas
    /// solo una gana.
    /// </summary>
    Task<bool> AcceptInvitationAsync(Guid invitationId, Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Pasa la invitación de pendiente a rechazada; false si ya no estaba pendiente.</summary>
    Task<bool> RejectInvitationAsync(Guid invitationId, CancellationToken cancellationToken = default);

    /// <summary>Las invitaciones pendientes del negocio, de la más antigua a la más reciente.</summary>
    Task<IReadOnlyList<Invitation>> ListPendingInvitationsOfBusinessAsync(
        Guid businessId, CancellationToken cancellationToken = default);

    /// <summary>Pasa la invitación de pendiente a cancelada; false si ya no estaba pendiente.</summary>
    Task<bool> CancelInvitationAsync(Guid invitationId, CancellationToken cancellationToken = default);

    /// <summary>Los miembros con pertenencia activa en el negocio, con su correo.</summary>
    Task<IReadOnlyList<TeamMemberView>> ListActiveTeamAsync(Guid businessId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Aplica un cambio de equipo de forma atómica: bloquea el negocio, carga todas sus
    /// pertenencias, deja que la regla del dominio decida y, solo si es válida, guarda lo que
    /// cambió. El bloqueo hace que dos cambios simultáneos se esperen entre sí, así que la regla
    /// del último dueño no se burla con dos bajas a la vez. Quitar a alguien deja constancia de
    /// la fecha y reinicia su "último lote" (RF-11, RF-12).
    /// </summary>
    Task<TeamResult> ChangeTeamAsync(
        Guid businessId,
        Func<IReadOnlyList<Member>, TeamResult> change,
        DateTime now,
        CancellationToken cancellationToken = default);
}
