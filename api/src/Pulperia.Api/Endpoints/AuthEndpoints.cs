using Pulperia.Application.Accounts;

namespace Pulperia.Api.Endpoints;

internal static class AuthEndpoints
{
    private sealed record RegisterBody(
        string? Email, string? Password, string? BusinessName, string? AmountMode, string? QuantityMode);

    public static void MapAuthEndpoints(this WebApplication app)
    {
        var auth = app.MapGroup("/api/auth");
        auth.MapPost("/register", RegisterAsync);
    }

    private static async Task<IResult> RegisterAsync(HttpContext context, AccountService accounts)
    {
        var body = await Http.ReadBodyAsync<RegisterBody>(context);
        if (body is not { Email: not null, Password: not null, BusinessName: not null, AmountMode: not null, QuantityMode: not null })
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

        var result = await accounts.RegisterAsync(
            new RegisterRequest(body.Email, body.Password, body.BusinessName, amountMode, quantityMode),
            context.RequestAborted);

        return result.IsSuccess
            ? Results.Json(
                new { userId = result.Value!.UserId, businessId = result.Value.BusinessId },
                Http.Json, statusCode: StatusCodes.Status201Created)
            : Http.Error(result.Codes[0] == "email_taken" ? StatusCodes.Status409Conflict : StatusCodes.Status400BadRequest, result.Codes);
    }
}
