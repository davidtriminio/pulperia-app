using Pulperia.Application.Accounts;
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

    Task<AdminAccount?> FindAccountAsync(Guid userId, CancellationToken cancellationToken = default);
}

/// <summary>Consulta de negocios y cuentas para super administradores (RF-97).</summary>
public sealed class PlatformService(IPlatformStore store)
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

    private static string? Clean(string? search) => string.IsNullOrWhiteSpace(search) ? null : search.Trim();

    private static int Page(int? page) => Math.Max(1, page ?? 1);

    private static int PageSize(int? size) => Math.Clamp(size ?? DefaultPageSize, 1, MaxPageSize);
}
