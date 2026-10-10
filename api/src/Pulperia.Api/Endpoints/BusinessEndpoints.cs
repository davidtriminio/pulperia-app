using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;

namespace Pulperia.Api.Endpoints;

internal static class BusinessEndpoints
{
    private sealed record CreateBusinessBody(string? Name, string? AmountMode, string? QuantityMode);

    public static void MapBusinessEndpoints(this WebApplication app)
    {
        var businesses = app.MapGroup("/api/businesses");
        businesses.MapGet("", ListAsync);
        businesses.MapPost("", CreateAsync);
    }

    internal static object Json(BusinessSummary business) => new
    {
        id = business.Id,
        name = business.Name,
        role = business.Role.Id(),
        amountMode = business.AmountMode.Id(),
        quantityMode = business.QuantityMode.Id(),
        status = business.Status.Id(),
    };

    private static async Task<IResult> ListAsync(HttpContext context, AccountService accounts)
    {
        if (await Http.AuthenticateAsync(context, accounts) is not { } user)
        {
            return Http.Unauthorized();
        }
        var list = await accounts.ListBusinessesAsync(user.UserId, context.RequestAborted);
        return Results.Json(list.Select(Json), Http.Json);
    }

    private static async Task<IResult> CreateAsync(HttpContext context, AccountService accounts)
    {
        if (await Http.AuthenticateAsync(context, accounts) is not { } user)
        {
            return Http.Unauthorized();
        }
        var body = await Http.ReadBodyAsync<CreateBusinessBody>(context);
        if (body is not { Name: not null, AmountMode: not null, QuantityMode: not null })
        {
            return Http.InvalidRequest();
        }
        if (Http.ParseAmountMode(body.AmountMode) is not { } amountMode)
        {
            return Http.Error(StatusCodes.Status400BadRequest, "amount_mode_invalid");
        }
        if (Http.ParseQuantityMode(body.QuantityMode) is not { } quantityMode)
        {
            return Http.Error(StatusCodes.Status400BadRequest, "quantity_mode_invalid");
        }

        var result = await accounts.CreateBusinessAsync(user.UserId, body.Name, amountMode, quantityMode, context.RequestAborted);
        return result.IsSuccess
            ? Results.Json(Json(result.Value!), Http.Json, statusCode: StatusCodes.Status201Created)
            : Http.Error(StatusCodes.Status400BadRequest, result.Codes);
    }
}
