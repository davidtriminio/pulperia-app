using Pulperia.Application.Accounts;
using Pulperia.Application.Management;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Domain.Invitations;

namespace Pulperia.Api.Endpoints;

/// <summary>
/// Rutas de gestión del negocio activo (<c>X-Business-Id</c>): ajustes, invitaciones y equipo.
/// Solo el dueño las usa (RF-13); el servicio rechaza al empleado con 403.
/// </summary>
internal static class ManagementEndpoints
{
    private sealed record InviteBody(string? Email);

    private sealed record SettingsBody(string? Name, string? AmountMode, string? QuantityMode);

    public static void MapManagementEndpoints(this WebApplication app)
    {
        var business = app.MapGroup("/api/business").RequireBusiness();
        business.MapGet("", GetSettingsAsync);
        business.MapPatch("", UpdateSettingsAsync);
        business.MapPost("/invitations", InviteAsync);
        business.MapGet("/invitations", ListBusinessInvitationsAsync);
        business.MapDelete("/invitations/{id:guid}", CancelInvitationAsync);
        business.MapGet("/team", ListTeamAsync);
        business.MapPost("/team/{userId:guid}/promote", PromoteAsync);

        // Las del invitado no llevan negocio activo: la invitación es de una persona, no de un negocio.
        var invitations = app.MapGroup("/api/invitations");
        invitations.MapGet("", ListInvitationsAsync);
        invitations.MapPost("/{id:guid}/accept", AcceptAsync);
        invitations.MapPost("/{id:guid}/reject", RejectAsync);
    }

    /// <summary>Traduce un rechazo del servicio a su estado HTTP.</summary>
    internal static IResult Failure(IReadOnlyList<string> codes) => Http.Error(
        codes[0] switch
        {
            "forbidden" or "invitation_not_invitee" => StatusCodes.Status403Forbidden,
            var code when code.EndsWith("_not_found") => StatusCodes.Status404NotFound,
            var code when code.StartsWith("team_") => StatusCodes.Status409Conflict,
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

    private static async Task<IResult> InviteAsync(HttpContext context, ManagementService management)
    {
        var active = context.GetActiveBusiness();
        var body = await Http.ReadBodyAsync<InviteBody>(context);
        if (body is not { Email: not null })
        {
            return Http.InvalidRequest();
        }
        var result = await management.InviteAsync(active.BusinessId, active.Role, active.UserId, body.Email, context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(
                new { id = result.Value!.Id, email = result.Value.Email, status = result.Value.Status.Id() },
                Http.Json, statusCode: StatusCodes.Status201Created)
            : Failure(result.Codes);
    }

    private static async Task<IResult> ListBusinessInvitationsAsync(HttpContext context, ManagementService management)
    {
        var active = context.GetActiveBusiness();
        var result = await management.ListBusinessInvitationsAsync(active.BusinessId, active.Role, context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(
                result.Value!.Select(i => new { id = i.Id, email = i.Email, status = i.Status.Id() }), Http.Json)
            : Failure(result.Codes);
    }

    private static async Task<IResult> CancelInvitationAsync(Guid id, HttpContext context, ManagementService management)
    {
        var active = context.GetActiveBusiness();
        var result = await management.CancelInvitationAsync(active.BusinessId, active.Role, id, context.RequestAborted);
        return result.IsSuccess ? Results.NoContent() : Failure(result.Codes);
    }

    private static async Task<IResult> ListTeamAsync(HttpContext context, ManagementService management)
    {
        var active = context.GetActiveBusiness();
        var result = await management.ListTeamAsync(active.BusinessId, active.Role, context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(result.Value!.Select(m => new { userId = m.UserId, email = m.Email, role = m.Role.Id() }), Http.Json)
            : Failure(result.Codes);
    }

    private static async Task<IResult> PromoteAsync(Guid userId, HttpContext context, ManagementService management)
    {
        var active = context.GetActiveBusiness();
        var result = await management.PromoteAsync(active.BusinessId, active.Role, userId, context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(new { userId = result.Value!.UserId, role = result.Value.Role.Id() }, Http.Json)
            : Failure(result.Codes);
    }

    private static async Task<IResult> ListInvitationsAsync(
        HttpContext context, AccountService accounts, ManagementService management)
    {
        if (await Http.AuthenticateAsync(context, accounts) is not { } user)
        {
            return Http.Unauthorized();
        }
        var offers = await management.ListInvitationsForUserAsync(user.UserId, context.RequestAborted);
        return Results.Json(
            offers.Select(o => new { id = o.Id, businessId = o.BusinessId, businessName = o.BusinessName, email = o.Email }),
            Http.Json);
    }

    private static async Task<IResult> AcceptAsync(
        Guid id, HttpContext context, AccountService accounts, ManagementService management)
    {
        if (await Http.AuthenticateAsync(context, accounts) is not { } user)
        {
            return Http.Unauthorized();
        }
        var result = await management.AcceptInvitationAsync(user.UserId, id, context.RequestAborted);
        return result.IsSuccess ? Results.Json(BusinessEndpoints.Json(result.Value!), Http.Json) : Failure(result.Codes);
    }

    private static async Task<IResult> RejectAsync(
        Guid id, HttpContext context, AccountService accounts, ManagementService management)
    {
        if (await Http.AuthenticateAsync(context, accounts) is not { } user)
        {
            return Http.Unauthorized();
        }
        var result = await management.RejectInvitationAsync(user.UserId, id, context.RequestAborted);
        return result.IsSuccess ? Results.NoContent() : Failure(result.Codes);
    }
}
