using Pulperia.Domain.Business;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>Tabla <c>businesses</c>: un negocio con sus modos de montos y cantidades.</summary>
public sealed class BusinessEntity
{
    public Guid Id { get; set; }

    public string Name { get; set; } = "";

    public AmountMode AmountMode { get; set; }

    public QuantityMode QuantityMode { get; set; }

    /// <summary>Último <c>seq</c> asignado en el registro de cambios del negocio.</summary>
    public long LastSeq { get; set; }

    public DateTime CreatedAt { get; set; }

    /// <summary>Pendiente de activación, activo o suspendido (D-30). Los negocios existentes son activos.</summary>
    public BusinessStatus Status { get; set; } = BusinessStatus.Active;

    /// <summary>El motivo de una suspensión o de un rechazo; null en los demás estados.</summary>
    public string? StatusReason { get; set; }
}
