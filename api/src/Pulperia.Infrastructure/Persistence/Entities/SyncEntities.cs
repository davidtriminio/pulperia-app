using Pulperia.Domain.Admin;
using Pulperia.Domain.Sync;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>change_log</c>: qué registro cambió y en qué orden, por negocio. Los dispositivos
/// piden "lo posterior a este <see cref="Seq"/>" (RF-52). Solo se agrega, nunca se edita ni se
/// borra.
/// </summary>
public sealed class ChangeLogEntity
{
    public Guid BusinessId { get; set; }

    /// <summary>Número de orden dentro del negocio, desde 1, sin huecos (<see cref="ChangeSequence"/>).</summary>
    public long Seq { get; set; }

    public ChangeEntityType EntityType { get; set; }

    public Guid EntityId { get; set; }
}

/// <summary>
/// Tabla <c>processed_ops</c>: las operaciones de los dispositivos que ya se procesaron, para
/// que reenviarlas no duplique nada (RF-53).
/// </summary>
public sealed class ProcessedOpEntity
{
    public Guid OpId { get; set; }

    public Guid BusinessId { get; set; }

    /// <summary><c>applied</c>, o el código de rechazo (por ejemplo <c>version_conflict</c>).</summary>
    public string Result { get; set; } = "";

    public DateTime ProcessedAt { get; set; }
}

/// <summary>
/// Tabla <c>admin_audit</c>: constancia de lo que el administrador del servidor hace a mano,
/// sin datos de ningún negocio (RF-81, RF-82). Solo se agrega.
/// </summary>
public sealed class AdminAuditEntity
{
    public Guid Id { get; set; }

    public AdminAction Action { get; set; }

    public Guid TargetUserId { get; set; }

    /// <summary>Identificador del operador que ejecutó el comando.</summary>
    public string PerformedBy { get; set; } = "";

    public DateTime PerformedAt { get; set; }
}
