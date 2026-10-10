using Pulperia.Application.Accounts;
using Pulperia.Domain.Accounts;
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
    /// En una sola transacción y con la cuenta bloqueada: aplica la regla, guarda la suspensión con
    /// su motivo (o la quita), al suspender cierra todas sus sesiones abiertas y escribe en
    /// <c>admin_audit</c> (RF-99, RF-101). No toca sus negocios ni sus pertenencias.
    /// </summary>
    Task<AccountSuspensionOutcome> ChangeAccountSuspensionAsync(
        Guid userId, bool suspend, string? reason, Guid performedByUserId, DateTime at,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// En una sola transacción y con el negocio bloqueado: aplica la transición del dominio,
    /// guarda el estado nuevo (con el motivo solo al suspender) y escribe en <c>admin_audit</c>
    /// quién, cuándo y por qué (RF-101). Si no se puede, no cambia ni audita nada.
    /// </summary>
    Task<BusinessStatusOutcome> ChangeBusinessStatusAsync(
        Guid businessId, Func<BusinessStatus, BusinessStatusChange> change, AdminAction action,
        Guid performedByUserId, string? reason, DateTime at, CancellationToken cancellationToken = default);

    Task<AdminAccount?> FindAccountAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>La auditoría de la más reciente a la más antigua, con filtros opcionales.</summary>
    Task<AdminPage<AdminAuditEntry>> ListAuditAsync(
        Guid? accountId, Guid? businessId, AdminAction? action, int page, int pageSize,
        CancellationToken cancellationToken = default);
}

/// <summary>El negocio con su estado nuevo, o el código estable del rechazo.</summary>
public sealed record BusinessStatusOutcome(AdminBusiness? Business, string? Code)
{
    public static BusinessStatusOutcome Done(AdminBusiness business) => new(business, null);

    public static BusinessStatusOutcome Fail(string code) => new(null, code);
}

/// <summary>La cuenta con su estado nuevo, o el código estable del rechazo.</summary>
public sealed record AccountSuspensionOutcome(AdminAccount? Account, string? Code)
{
    public static AccountSuspensionOutcome Done(AdminAccount account) => new(account, null);

    public static AccountSuspensionOutcome Fail(string code) => new(null, code);
}

/// <summary>Consulta de negocios y cuentas, y su suspensión, para super administradores (RF-97, RF-98).</summary>
public sealed class PlatformService(IPlatformStore store, PasswordResetService passwordReset, TimeProvider clock)
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

    public Task<AdminPage<AdminAuditEntry>> ListAuditAsync(
        Guid? accountId, Guid? businessId, AdminAction? action, int? page, int? pageSize,
        CancellationToken cancellationToken = default) =>
        store.ListAuditAsync(accountId, businessId, action, Page(page), PageSize(pageSize), cancellationToken);

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

    /// <summary>
    /// Activa un negocio pendiente (RF-103, D-30): desde entonces trabaja con normalidad. Rechazarlo
    /// es suspenderlo con un motivo.
    /// </summary>
    public async Task<AccountResult<AdminBusiness>> ActivateBusinessAsync(
        Guid businessId, Guid performedByUserId, CancellationToken cancellationToken = default) =>
        Wrap(await store.ChangeBusinessStatusAsync(
            businessId, BusinessStatusRules.Activate, AdminAction.ActivateBusiness,
            performedByUserId, null, clock.GetUtcNow().UtcDateTime, cancellationToken));

    /// <summary>Reactiva un negocio suspendido (RF-98): todo vuelve a funcionar y la cola pendiente se aplica.</summary>
    public async Task<AccountResult<AdminBusiness>> ReactivateBusinessAsync(
        Guid businessId, Guid performedByUserId, CancellationToken cancellationToken = default) =>
        Wrap(await store.ChangeBusinessStatusAsync(
            businessId, BusinessStatusRules.Reactivate, AdminAction.ReactivateBusiness,
            performedByUserId, null, clock.GetUtcNow().UtcDateTime, cancellationToken));

    /// <summary>
    /// Suspende la cuenta con un motivo (RF-99): no inicia sesión y sus sesiones se cierran. Un super
    /// administrador no puede suspender su propia cuenta: se quedaría sin acceso al panel.
    /// </summary>
    public async Task<AccountResult<AdminAccount>> SuspendAccountAsync(
        Guid userId, string? reason, Guid performedByUserId, CancellationToken cancellationToken = default)
    {
        if (userId == performedByUserId)
        {
            return AccountResult<AdminAccount>.Fail("cannot_suspend_self");
        }
        return Wrap(await store.ChangeAccountSuspensionAsync(
            userId, suspend: true, Clean(reason), performedByUserId, clock.GetUtcNow().UtcDateTime, cancellationToken));
    }

    public async Task<AccountResult<AdminAccount>> ReactivateAccountAsync(
        Guid userId, Guid performedByUserId, CancellationToken cancellationToken = default) =>
        Wrap(await store.ChangeAccountSuspensionAsync(
            userId, suspend: false, null, performedByUserId, clock.GetUtcNow().UtcDateTime, cancellationToken));

    /// <summary>
    /// Restablece la contraseña de la cuenta desde el panel (RF-100): genera una nueva, que se
    /// entrega una sola vez, cierra sus sesiones y queda en la auditoría. No toca datos de negocios.
    /// </summary>
    public async Task<AccountResult<string>> ResetPasswordAsync(
        Guid userId, Guid performedByUserId, CancellationToken cancellationToken = default)
    {
        if (await store.FindAccountAsync(userId, cancellationToken) is not { } target
            || await store.FindAccountAsync(performedByUserId, cancellationToken) is not { } performer)
        {
            return AccountResult<string>.Fail("account_not_found");
        }
        return await passwordReset.ResetPasswordAsync(target.Email, performer.Email, cancellationToken);
    }

    private static AccountResult<AdminAccount> Wrap(AccountSuspensionOutcome outcome) =>
        outcome.Account is { } account
            ? AccountResult<AdminAccount>.Ok(account)
            : AccountResult<AdminAccount>.Fail(outcome.Code!);

    private static AccountResult<AdminBusiness> Wrap(BusinessStatusOutcome outcome) =>
        outcome.Business is { } business
            ? AccountResult<AdminBusiness>.Ok(business)
            : AccountResult<AdminBusiness>.Fail(outcome.Code!);

    private static string? Clean(string? search) => string.IsNullOrWhiteSpace(search) ? null : search.Trim();

    private static int Page(int? page) => Math.Max(1, page ?? 1);

    private static int PageSize(int? size) => Math.Clamp(size ?? DefaultPageSize, 1, MaxPageSize);
}
