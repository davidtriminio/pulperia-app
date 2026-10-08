using Pulperia.Domain.Access;
using Pulperia.Domain.Team;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>memberships</c>: la pertenencia de un usuario a un negocio, con su rol en él
/// (RF-5, RF-6). Quitar a alguien no la borra: pasa a <see cref="MembershipStatus.Removed"/>.
/// </summary>
public sealed class MembershipEntity
{
    public Guid UserId { get; set; }

    public Guid BusinessId { get; set; }

    public Role Role { get; set; }

    public MembershipStatus Status { get; set; } = MembershipStatus.Active;

    public DateTime? RemovedAt { get; set; }

    /// <summary>Si el usuario removido ya usó su último lote de sincronización (RF-12).</summary>
    public bool FinalSyncUsed { get; set; }

    /// <summary>Del dominio a la base. <paramref name="now"/> es la fecha de baja si el miembro está removido.</summary>
    public static MembershipEntity FromDomain(Member member, Guid businessId, DateTime now) => new()
    {
        UserId = member.UserId,
        BusinessId = businessId,
        Role = member.Role,
        Status = member.Status,
        RemovedAt = member.Status == MembershipStatus.Removed ? now : null,
    };

    public Member ToDomain() => new(UserId, Role, Status);
}
