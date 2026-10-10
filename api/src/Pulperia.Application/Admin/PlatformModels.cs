using Pulperia.Domain.Access;
using Pulperia.Domain.Admin;
using Pulperia.Domain.Business;

namespace Pulperia.Application.Admin;

/// <summary>
/// Lo que el panel ve de un negocio (RF-97, D-29): metadatos y cifras agregadas, nunca nombres de
/// clientes ni de productos, montos ni deudas. Los conteos incluyen lo archivado y lo anulado.
/// </summary>
public sealed record AdminBusiness(
    Guid Id,
    string Name,
    IReadOnlyList<string> OwnerEmails,
    int MemberCount,
    DateTime CreatedAt,
    BusinessStatus Status,
    string? StatusReason,
    DateTime? LastSyncAt,
    int ClientCount,
    int ProductCount,
    int FiadoCount,
    int PaymentCount);

/// <summary>Un negocio al que pertenece una cuenta, con su rol y su estado.</summary>
public sealed record AdminAccountBusiness(Guid Id, string Name, Role Role, BusinessStatus Status);

/// <summary>Lo que el panel ve de una cuenta: correo, alta, estado y negocios (RF-97).</summary>
public sealed record AdminAccount(
    Guid Id,
    string Email,
    DateTime CreatedAt,
    bool IsSuperAdmin,
    DateTime? SuspendedAt,
    string? SuspensionReason,
    IReadOnlyList<AdminAccountBusiness> Businesses);

/// <summary>
/// Una entrada de la auditoría (RF-101): quién, cuándo, qué, sobre qué cuenta o negocio y el
/// motivo. Del negocio solo se muestra su identificador y su nombre.
/// </summary>
public sealed record AdminAuditEntry(
    Guid Id,
    AdminAction Action,
    string PerformedBy,
    DateTime PerformedAt,
    Guid? TargetUserId,
    string? TargetEmail,
    Guid? TargetBusinessId,
    string? TargetBusinessName,
    string? Detail);

/// <summary>Una página de resultados, con el total para poder paginar.</summary>
public sealed record AdminPage<T>(IReadOnlyList<T> Items, int Page, int PageSize, int Total);
