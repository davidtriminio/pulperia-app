using Pulperia.Application.Accounts;
using Pulperia.Domain.Admin;
using Pulperia.Domain.Business;

namespace Pulperia.Application.Admin;

/// <summary>
/// Lo que el panel de administración necesita de la base de datos. Todas las lecturas son
/// consultas agregadas dedicadas: ninguna toca nombres de clientes ni de productos, montos ni
/// deudas (RF-82, RF-97, D-29).
/// </summary>
public interface IPlatformStore
{
    Task<AdminPage<AdminBusiness>> ListBusinessesAsync(
        string? search, BusinessStatus? status, int page, int pageSize, CancellationToken cancellationToken = default);

    Task<AdminBusiness?> FindBusinessAsync(Guid businessId, CancellationToken cancellationToken = default);

    Task<AdminPage<AdminAccount>> ListAccountsAsync(
        string? search, int page, int pageSize, CancellationToken cancellationToken = default);

    /// <summary>
    /// En una sola transacción y con el negocio bloqueado: aplica la transición del dominio,
    /// guarda el estado nuevo (con el motivo solo al suspender) y escribe en <c>admin_audit</c>
    /// quién, cuándo y por qué (RF-101). Si no se puede, no cambia ni audita nada.
    /// </summary>
    Task<BusinessStatusOutcome> ChangeBusinessStatusAsync(
        Guid businessId, Func<BusinessStatus, BusinessStatusChange> change, AdminAction action,
        Guid performedByUserId, string? reason, DateTime at, CancellationToken cancellationToken = default);

    Task<AdminAccount?> FindAccountAsync(Guid userId, CancellationToken cancellationToken = default);
}

/// <summary>El negocio con su estado nuevo, o el código estable del rechazo.</summary>
public sealed record BusinessStatusOutcome(AdminBusiness? Business, string? Code)
{
    public static BusinessStatusOutcome Done(AdminBusiness business) => new(business, null);

    public static BusinessStatusOutcome Fail(string code) => new(null, code);
}

/// <summary>Consulta de negocios y cuentas, y su suspensión, para super administradores (RF-97, RF-98).</summary>
public sealed class PlatformService(IPlatformStore store, TimeProvider clock)
{
    public const int DefaultPageSize = 25;
    public const int MaxPageSize = 100;

    public Task<AdminPage<AdminBusiness>> ListBusinessesAsync(
        string? search, BusinessStatus? status, int? page, int? pageSize, CancellationToken cancellationToken = default) =>
        store.ListBusinessesAsync(Clean(search), status, Page(page), PageSize(pageSize), cancellationToken);

    public async Task<AccountResult<AdminBusiness>> GetBusinessAsync(
        Guid businessId, CancellationToken cancellationToken = default) =>
        await store.FindBusinessAsync(businessId, cancellationToken) is { } business
            ? AccountResult<AdminBusiness>.Ok(business)
            : AccountResult<AdminBusiness>.Fail("business_not_found");

    public Task<AdminPage<AdminAccount>> ListAccountsAsync(
        string? search, int? page, int? pageSize, CancellationToken cancellationToken = default) =>
        store.ListAccountsAsync(Clean(search), Page(page), PageSize(pageSize), cancellationToken);

    public async Task<AccountResult<AdminAccount>> GetAccountAsync(
        Guid userId, CancellationToken cancellationToken = default) =>
        await store.FindAccountAsync(userId, cancellationToken) is { } account
            ? AccountResult<AdminAccount>.Ok(account)
            : AccountResult<AdminAccount>.Fail("account_not_found");

    /// <summary>Suspende el negocio con un motivo (RF-98): conserva sus datos y rechaza sus peticiones.</summary>
    public async Task<AccountResult<AdminBusiness>> SuspendBusinessAsync(
        Guid businessId, string? reason, Guid performedByUserId, CancellationToken cancellationToken = default)
    {
        var clean = Clean(reason);
        return Wrap(await store.ChangeBusinessStatusAsync(
            businessId, current => BusinessStatusRules.Suspend(current, clean), AdminAction.SuspendBusiness,
            performedByUserId, clean, clock.GetUtcNow().UtcDateTime, cancellationToken));
    }

    /// <summary>Reactiva un negocio suspendido (RF-98): todo vuelve a funcionar y la cola pendiente se aplica.</summary>
    public async Task<AccountResult<AdminBusiness>> ReactivateBusinessAsync(
        Guid businessId, Guid performedByUserId, CancellationToken cancellationToken = default) =>
        Wrap(await store.ChangeBusinessStatusAsync(
            businessId, BusinessStatusRules.Reactivate, AdminAction.ReactivateBusiness,
            performedByUserId, null, clock.GetUtcNow().UtcDateTime, cancellationToken));

    private static AccountResult<AdminBusiness> Wrap(BusinessStatusOutcome outcome) =>
        outcome.Business is { } business
            ? AccountResult<AdminBusiness>.Ok(business)
            : AccountResult<AdminBusiness>.Fail(outcome.Code!);

    private static string? Clean(string? search) => string.IsNullOrWhiteSpace(search) ? null : search.Trim();

    private static int Page(int? page) => Math.Max(1, page ?? 1);

    private static int PageSize(int? size) => Math.Clamp(size ?? DefaultPageSize, 1, MaxPageSize);
}
