using Pulperia.Domain.Access;

namespace Pulperia.Domain.Team;

public enum MembershipStatus
{
    Active,
    Removed,
}

/// <summary>
/// Pertenencia de un usuario a un negocio. Quitar a alguien no borra su pertenencia: pasa a
/// <see cref="MembershipStatus.Removed"/> (la fecha de baja y el último lote del RF-12 los
/// maneja la persistencia).
/// </summary>
public sealed record Member(Guid UserId, Role Role, MembershipStatus Status = MembershipStatus.Active);

/// <summary>Motivo por el que se rechaza una acción sobre el equipo.</summary>
public enum TeamError
{
    /// <summary>La persona no pertenece al negocio.</summary>
    MemberNotFound,

    /// <summary>La persona ya fue quitada del negocio.</summary>
    MemberNotActive,

    /// <summary>Promover a quien ya es dueño (RF-70 habla de promover a un empleado).</summary>
    AlreadyOwner,

    /// <summary>La acción dejaría al negocio sin ningún dueño (RF-71).</summary>
    LastOwner,
}

public static class TeamErrors
{
    /// <summary>Código estable para la API.</summary>
    public static string Code(this TeamError error) => error switch
    {
        TeamError.MemberNotFound => "team_member_not_found",
        TeamError.MemberNotActive => "team_member_not_active",
        TeamError.AlreadyOwner => "team_already_owner",
        TeamError.LastOwner => "team_last_owner",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

/// <summary>El equipo resultante de una acción válida, o el motivo del rechazo.</summary>
public readonly record struct TeamResult(IReadOnlyList<Member>? Team, TeamError? Error)
{
    public bool IsValid => Team is not null;

    public static TeamResult Ok(IReadOnlyList<Member> team) => new(team, null);

    public static TeamResult Fail(TeamError error) => new(null, error);
}

/// <summary>
/// Reglas del equipo de un negocio: promoción a dueño, baja y protección del último dueño.
/// Son funciones puras: devuelven el equipo nuevo y no modifican el que reciben. El permiso
/// para ejecutarlas (solo un dueño, RF-13) lo comprueba la capa que las llama.
/// </summary>
public static class TeamRules
{
    /// <summary>Cantidad de dueños con pertenencia activa.</summary>
    public static int ActiveOwnerCount(IEnumerable<Member> team) =>
        team.Count(m => m.Role == Role.Owner && m.Status == MembershipStatus.Active);

    /// <summary>
    /// Promueve a un empleado activo a dueño, con todos los permisos de dueño (RF-70).
    /// </summary>
    public static TeamResult Promote(IReadOnlyList<Member> team, Guid userId)
    {
        var member = team.FirstOrDefault(m => m.UserId == userId);
        if (member is null)
        {
            return TeamResult.Fail(TeamError.MemberNotFound);
        }
        if (member.Status != MembershipStatus.Active)
        {
            return TeamResult.Fail(TeamError.MemberNotActive);
        }
        if (member.Role == Role.Owner)
        {
            return TeamResult.Fail(TeamError.AlreadyOwner);
        }

        return TeamResult.Ok(Replace(team, member with { Role = Role.Owner }));
    }

    /// <summary>
    /// Quita a un usuario del negocio (RF-11). Se rechaza si dejaría al negocio sin ningún
    /// dueño activo (RF-71).
    /// </summary>
    public static TeamResult Remove(IReadOnlyList<Member> team, Guid userId)
    {
        var member = team.FirstOrDefault(m => m.UserId == userId);
        if (member is null)
        {
            return TeamResult.Fail(TeamError.MemberNotFound);
        }
        if (member.Status != MembershipStatus.Active)
        {
            return TeamResult.Fail(TeamError.MemberNotActive);
        }
        if (member.Role == Role.Owner && ActiveOwnerCount(team) <= 1)
        {
            return TeamResult.Fail(TeamError.LastOwner);
        }

        return TeamResult.Ok(Replace(team, member with { Status = MembershipStatus.Removed }));
    }

    private static List<Member> Replace(IReadOnlyList<Member> team, Member updated) =>
        team.Select(m => m.UserId == updated.UserId ? updated : m).ToList();
}
