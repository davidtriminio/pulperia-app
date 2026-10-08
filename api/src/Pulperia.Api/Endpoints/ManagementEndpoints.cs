using Pulperia.Application.Accounts;
using Pulperia.Application.Management;
using Pulperia.Domain.Business;

namespace Pulperia.Api.Endpoints;

/// <summary>
/// Rutas de gestión del negocio activo (<c>X-Business-Id</c>): ajustes, invitaciones y equipo.
/// Solo el dueño las usa (RF-13); el servicio rechaza al empleado con 403.
/// </summary>
internal static class ManagementEndpoints
{
    private sealed record SettingsBody(string? Name, string? AmountMode, string? QuantityMode);

    public static void MapManagementEndpoints(this WebApplication app)
    {
        var business = app.MapGroup("/api/business").RequireBusiness();
        business.MapGet("", GetSettingsAsync);
        business.MapPatch("", UpdateSettingsAsync);
    }

    /// <summary>Traduce un rechazo del servicio a su estado HTTP.</summary>
    internal static IResult Failure(IReadOnlyList<string> codes) => Http.Error(
        codes[0] switch
        {
            "forbidden" => StatusCodes.Status403Forbidden,
            var code when code.EndsWith("_not_found") => StatusCodes.Status404NotFound,
            var code when code.EndsWith("_already_pending") || code is "already_member" || code.EndsWith("_not_pending")
                => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest,
        },
        codes);

    private static object Json(BusinessSettings settings) => new
    {
        name = settings.Name,
        amountMode = settings.AmountMode.Id(),
        quantityMode = settings.QuantityMode.Id(),
    };

    private static async Task<IResult> GetSettingsAsync(HttpContext context, ManagementService management)
    {
        var active = context.GetActiveBusiness();
        var result = await management.GetSettingsAsync(active.BusinessId, active.Role, context.RequestAborted);
        return result.IsSuccess ? Results.Json(Json(result.Value!), Http.Json) : Failure(result.Codes);
    }

    private static async Task<IResult> UpdateSettingsAsync(HttpContext context, ManagementService management)
    {
        var active = context.GetActiveBusiness();
        var body = await Http.ReadBodyAsync<SettingsBody>(context);
        if (body is null)
        {
            return Http.InvalidRequest();
        }

        AmountMode? amountMode = null;
        if (body.AmountMode is not null)
        {
            amountMode = Http.ParseAmountMode(body.AmountMode);
            if (amountMode is null)
            {
                return Http.Error(StatusCodes.Status400BadRequest, "amount_mode_invalid");
            }
        }
        QuantityMode? quantityMode = null;
        if (body.QuantityMode is not null)
        {
            quantityMode = Http.ParseQuantityMode(body.QuantityMode);
            if (quantityMode is null)
            {
                return Http.Error(StatusCodes.Status400BadRequest, "quantity_mode_invalid");
            }
        }

        var result = await management.UpdateSettingsAsync(
            active.BusinessId, active.Role, new SettingsChange(body.Name, amountMode, quantityMode), context.RequestAborted);
        return result.IsSuccess ? Results.Json(Json(result.Value!), Http.Json) : Failure(result.Codes);
    }
}
