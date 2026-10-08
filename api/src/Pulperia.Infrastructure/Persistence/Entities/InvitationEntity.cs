using Pulperia.Domain.Invitations;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>invitations</c>: una invitación a un negocio asociada a un correo (RF-10). No
/// tiene fecha de vencimiento: sigue vigente hasta que se acepte, se rechace o se cancele.
/// </summary>
public sealed class InvitationEntity
{
    public Guid Id { get; set; }

    public Guid BusinessId { get; set; }

    /// <summary>Correo ya normalizado (sin espacios exteriores y en minúsculas).</summary>
    public string Email { get; set; } = "";

    public InvitationStatus Status { get; set; } = InvitationStatus.Pending;

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public static InvitationEntity FromDomain(Invitation invitation, Guid createdBy, DateTime createdAt) => new()
    {
        Id = invitation.Id,
        BusinessId = invitation.BusinessId,
        Email = invitation.Email,
        Status = invitation.Status,
        CreatedBy = createdBy,
        CreatedAt = createdAt,
    };

    public Invitation ToDomain() => new(Id, BusinessId, Email, Status);
}
