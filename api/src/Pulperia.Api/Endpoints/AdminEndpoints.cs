using Pulperia.Application.Admin;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;

namespace Pulperia.Api.Endpoints;

/// <summary>
/// Las rutas de <c>/api/admin</c> (D-29): solo para super administradores y sin negocio activo.
/// Cada respuesta se arma con metadatos y cifras agregadas; nunca con datos de un negocio.
/// </summary>
internal static class AdminEndpoints
{
    public static void MapAdminEndpoints(this WebApplication app)
    {
        var admin = app.MapAdminGroup();
        admin.MapGet("/businesses", ListBusinessesAsync);
        admin.MapGet("/businesses/{id:guid}", GetBusinessAsync);
        admin.MapGet("/accounts", ListAccountsAsync);
        admin.MapGet("/accounts/{id:guid}", GetAccountAsync);
    }

    private static object Json(AdminBusiness b) => new
    {
        id = b.Id,
        name = b.Name,
        ownerEmails = b.OwnerEmails,
        memberCount = b.MemberCount,
        createdAt = b.CreatedAt,
        status = b.Status.Id(),
        statusReason = b.StatusReason,
        lastSyncAt = b.LastSyncAt,
        clientCount = b.ClientCount,
        productCount = b.ProductCount,
        fiadoCount = b.FiadoCount,
        paymentCount = b.PaymentCount,
    };

    private static object Json(AdminAccount a) => new
    {
        id = a.Id,
        email = a.Email,
        createdAt = a.CreatedAt,
        isSuperAdmin = a.IsSuperAdmin,
        suspendedAt = a.SuspendedAt,
        suspensionReason = a.SuspensionReason,
        businesses = a.Businesses.Select(b => new { id = b.Id, name = b.Name, role = b.Role.Id(), status = b.Status.Id() }),
    };

    private static object Json<T>(AdminPage<T> page, Func<T, object> item) => new
    {
        items = page.Items.Select(item),
        page = page.Page,
        pageSize = page.PageSize,
        total = page.Total,
    };

    private static IResult NotFound(IReadOnlyList<string> codes) => Http.Error(StatusCodes.Status404NotFound, codes);

    private static async Task<IResult> ListBusinessesAsync(
        PlatformService platform, HttpContext context, string? search, string? status, int? page, int? pageSize)
    {
        BusinessStatus? wanted = null;
        if (status is not null)
        {
            try
            {
                wanted = BusinessStatuses.FromId(status);
            }
            catch (ArgumentException)
            {
                return Http.Error(StatusCodes.Status400BadRequest, "invalid_request");
            }
        }
        var result = await platform.ListBusinessesAsync(search, wanted, page, pageSize, context.RequestAborted);
        return Results.Json(Json(result, b => Json(b)), Http.Json);
    }

    private static async Task<IResult> GetBusinessAsync(Guid id, PlatformService platform, HttpContext context)
    {
        var result = await platform.GetBusinessAsync(id, context.RequestAborted);
        return result.IsSuccess ? Results.Json(Json(result.Value!), Http.Json) : NotFound(result.Codes);
    }

    private static async Task<IResult> ListAccountsAsync(
        PlatformService platform, HttpContext context, string? search, int? page, int? pageSize)
    {
        var result = await platform.ListAccountsAsync(search, page, pageSize, context.RequestAborted);
        return Results.Json(Json(result, a => Json(a)), Http.Json);
    }

    private static async Task<IResult> GetAccountAsync(Guid id, PlatformService platform, HttpContext context)
    {
        var result = await platform.GetAccountAsync(id, context.RequestAborted);
        return result.IsSuccess ? Results.Json(Json(result.Value!), Http.Json) : NotFound(result.Codes);
    }
}
