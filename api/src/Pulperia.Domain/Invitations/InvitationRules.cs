using Pulperia.Domain.Access;

namespace Pulperia.Domain.Invitations;

public enum InvitationStatus
{
    Pending,
    Accepted,
    Rejected,
    Cancelled,
}

public static class InvitationStatuses
{
    /// <summary>Identificador estable del estado, para la API y la base de datos.</summary>
    public static string Id(this InvitationStatus status) => status switch
    {
        InvitationStatus.Pending => "pending",
        InvitationStatus.Accepted => "accepted",
        InvitationStatus.Rejected => "rejected",
        InvitationStatus.Cancelled => "cancelled",
        _ => throw new ArgumentOutOfRangeException(nameof(status)),
    };
}

/// <summary>
/// Invitación a un negocio, asociada a un correo. No caduca: sigue vigente hasta que se
/// acepte, se rechace o un dueño la cancele (RF-10).
/// </summary>
/// <param name="Email">El correo ya normalizado (sin espacios exteriores y en minúsculas).</param>
public sealed record Invitation(Guid Id, Guid BusinessId, string Email, InvitationStatus Status);

/// <summary>Motivo por el que se rechaza una acción sobre una invitación.</summary>
public enum InvitationError
{
    /// <summary>Solo se puede responder o cancelar una invitación pendiente.</summary>
    NotPending,

    /// <summary>La persona que responde no es la invitada: el correo no coincide.</summary>
    NotInvitee,
}

public static class InvitationErrors
{
    /// <summary>Código estable para la API.</summary>
    public static string Code(this InvitationError error) => error switch
    {
        InvitationError.NotPending => "invitation_not_pending",
        InvitationError.NotInvitee => "invitation_not_invitee",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

/// <summary>La invitación resultante de una acción válida, o el motivo del rechazo.</summary>
/// <param name="NewMemberRole">Rol con el que entra al negocio quien acepta; null si no se aceptó.</param>
public readonly record struct InvitationResult(Invitation? Invitation, InvitationError? Error, Role? NewMemberRole)
{
    public bool IsValid => Invitation is not null;

    public static InvitationResult Ok(Invitation invitation, Role? newMemberRole = null) =>
        new(invitation, null, newMemberRole);

    public static InvitationResult Fail(InvitationError error) => new(null, error, null);
}

/// <summary>
/// Estados y transiciones de una invitación: <c>Pending</c> pasa a <c>Accepted</c>,
/// <c>Rejected</c> o <c>Cancelled</c>, y desde ahí no hay más cambios. Son funciones puras. El
/// permiso para cancelar (solo un dueño, RF-13) lo comprueba la capa que las llama.
/// </summary>
public static class InvitationRules
{
    /// <summary>Correo en su forma comparable: sin espacios exteriores y en minúsculas.</summary>
    public static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    public static bool SameEmail(string a, string b) => NormalizeEmail(a) == NormalizeEmail(b);

    /// <summary>Una invitación nueva queda pendiente y asociada al correo (RF-10).</summary>
    public static Invitation Create(Guid id, Guid businessId, string email) =>
        new(id, businessId, NormalizeEmail(email), InvitationStatus.Pending);

    /// <summary>
    /// La persona invitada acepta una invitación pendiente y entra al negocio como empleado,
    /// aunque ya pertenezca a otros (RF-67, RF-68).
    /// </summary>
    public static InvitationResult Accept(Invitation invitation, string userEmail) =>
        Respond(invitation, userEmail, InvitationStatus.Accepted, Role.Employee);

    /// <summary>La persona invitada rechaza una invitación pendiente (RF-67).</summary>
    public static InvitationResult Reject(Invitation invitation, string userEmail) =>
        Respond(invitation, userEmail, InvitationStatus.Rejected, null);

    /// <summary>
    /// Un dueño cancela una invitación pendiente: ya no podrá aceptarse (RF-69).
    /// </summary>
    public static InvitationResult Cancel(Invitation invitation) =>
        invitation.Status == InvitationStatus.Pending
            ? InvitationResult.Ok(invitation with { Status = InvitationStatus.Cancelled })
            : InvitationResult.Fail(InvitationError.NotPending);

    /// <summary>
    /// Las invitaciones pendientes de ese correo, para mostrarlas al iniciar sesión o al crear
    /// la cuenta (RF-67).
    /// </summary>
    public static IReadOnlyList<Invitation> PendingFor(string userEmail, IEnumerable<Invitation> invitations) =>
        invitations
            .Where(i => i.Status == InvitationStatus.Pending && SameEmail(i.Email, userEmail))
            .ToList();

    private static InvitationResult Respond(
        Invitation invitation, string userEmail, InvitationStatus target, Role? newMemberRole)
    {
        // Primero se comprueba quién responde: a un extraño no se le revela el estado.
        if (!SameEmail(invitation.Email, userEmail))
        {
            return InvitationResult.Fail(InvitationError.NotInvitee);
        }
        if (invitation.Status != InvitationStatus.Pending)
        {
            return InvitationResult.Fail(InvitationError.NotPending);
        }
        return InvitationResult.Ok(invitation with { Status = target }, newMemberRole);
    }
}
