namespace Pulperia.Domain.Business;

/// <summary>
/// Estado de un negocio en la plataforma (D-30): pendiente de activación, activo o suspendido. Un
/// negocio pendiente o suspendido rechaza peticiones y sincronización sin perder ningún dato.
/// </summary>
public enum BusinessStatus
{
    Pending,
    Active,
    Suspended,
}

public static class BusinessStatuses
{
    /// <summary>Identificador estable, el mismo de la base de datos y de la API.</summary>
    public static string Id(this BusinessStatus status) => status switch
    {
        BusinessStatus.Pending => "pending",
        BusinessStatus.Active => "active",
        BusinessStatus.Suspended => "suspended",
        _ => throw new ArgumentOutOfRangeException(nameof(status)),
    };

    public static BusinessStatus FromId(string id) => id switch
    {
        "pending" => BusinessStatus.Pending,
        "active" => BusinessStatus.Active,
        "suspended" => BusinessStatus.Suspended,
        _ => throw new ArgumentException($"Estado de negocio desconocido: {id}", nameof(id)),
    };
}

/// <summary>Motivo por el que se rechaza un cambio de estado del negocio.</summary>
public enum BusinessStatusError
{
    InvalidTransition,
    ReasonRequired,
}

public static class BusinessStatusErrors
{
    /// <summary>Código estable para los clientes (RNF-5).</summary>
    public static string Code(this BusinessStatusError error) => error switch
    {
        BusinessStatusError.InvalidTransition => "business_status_invalid_transition",
        BusinessStatusError.ReasonRequired => "reason_required",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

/// <summary>El resultado de pedir un cambio de estado: el estado nuevo, o por qué no se puede.</summary>
public readonly record struct BusinessStatusChange(bool IsValid, BusinessStatus Status, BusinessStatusError? Error)
{
    public static BusinessStatusChange To(BusinessStatus status) => new(true, status, null);

    public static BusinessStatusChange Deny(BusinessStatus current, BusinessStatusError error) => new(false, current, error);
}

/// <summary>
/// Las únicas transiciones válidas (D-30): pendiente a activo (activar) o a suspendido (rechazar),
/// activo a suspendido (suspender) y suspendido a activo (reactivar). Suspender o rechazar exige un
/// motivo.
/// </summary>
public static class BusinessStatusRules
{
    public static BusinessStatusChange Activate(BusinessStatus current) =>
        current == BusinessStatus.Pending
            ? BusinessStatusChange.To(BusinessStatus.Active)
            : BusinessStatusChange.Deny(current, BusinessStatusError.InvalidTransition);

    public static BusinessStatusChange Suspend(BusinessStatus current, string? reason)
    {
        if (current == BusinessStatus.Suspended)
        {
            return BusinessStatusChange.Deny(current, BusinessStatusError.InvalidTransition);
        }
        return string.IsNullOrWhiteSpace(reason)
            ? BusinessStatusChange.Deny(current, BusinessStatusError.ReasonRequired)
            : BusinessStatusChange.To(BusinessStatus.Suspended);
    }

    public static BusinessStatusChange Reactivate(BusinessStatus current) =>
        current == BusinessStatus.Suspended
            ? BusinessStatusChange.To(BusinessStatus.Active)
            : BusinessStatusChange.Deny(current, BusinessStatusError.InvalidTransition);
}
