using Pulperia.Domain.Access;
using Pulperia.Domain.Team;

namespace Pulperia.Application.Sync;

/// <summary>Qué pasó con una operación de un lote (plan 4.2).</summary>
public enum OutcomeStatus
{
    /// <summary>Se aplicó ahora.</summary>
    Applied,

    /// <summary>Ya se había procesado antes y se aplicó entonces: no se repite (RF-53).</summary>
    Duplicate,

    /// <summary>Se rechazó, con su código estable.</summary>
    Rejected,
}

/// <summary>El resultado de una operación del lote, con el <c>op_id</c> con el que el dispositivo la reconoce.</summary>
public sealed record OperationOutcome(Guid OpId, OutcomeStatus Status, IReadOnlyList<string> Codes)
{
    private static readonly IReadOnlyList<string> NoCodes = [];

    /// <summary>El código principal del rechazo; null si no se rechazó.</summary>
    public string? Code => Codes.Count == 0 ? null : Codes[0];

    public static OperationOutcome Applied(Guid opId) => new(opId, OutcomeStatus.Applied, NoCodes);

    public static OperationOutcome Duplicate(Guid opId) => new(opId, OutcomeStatus.Duplicate, NoCodes);

    public static OperationOutcome Rejected(Guid opId, IReadOnlyList<string> codes) =>
        new(opId, OutcomeStatus.Rejected, codes);
}

/// <summary>La pertenencia de un usuario al negocio de la sincronización (RF-6, RF-12).</summary>
public sealed record SyncMembership(Role Role, MembershipStatus Status, bool FinalSyncUsed);
