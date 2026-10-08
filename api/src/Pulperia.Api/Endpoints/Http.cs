using System.Text.Json;
using Pulperia.Application.Accounts;
using Pulperia.Domain.Business;

namespace Pulperia.Api.Endpoints;

/// <summary>Lectura del cuerpo y forma común de los errores: <c>{ "code": "...", "codes": [...] }</c> (RNF-5).</summary>
internal static class Http
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <summary>El cuerpo JSON como <typeparamref name="T"/>, o null si falta o no tiene esa forma.</summary>
    public static async Task<T?> ReadBodyAsync<T>(HttpContext context) where T : class
    {
        try
        {
            return await JsonSerializer.DeserializeAsync<T>(context.Request.Body, Json, context.RequestAborted);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>El token de la cabecera <c>Authorization: Bearer ...</c>, o null si falta.</summary>
    public static string? BearerToken(HttpContext context)
    {
        var header = context.Request.Headers.Authorization.ToString();
        const string prefix = "Bearer ";
        return header.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) && header.Length > prefix.Length
            ? header[prefix.Length..].Trim()
            : null;
    }

    /// <summary>El usuario del token de acceso de la petición, o null si falta, caducó o se cerró la sesión.</summary>
    public static async Task<AuthenticatedUser?> AuthenticateAsync(HttpContext context, AccountService accounts) =>
        BearerToken(context) is { } token ? await accounts.AuthenticateAsync(token, context.RequestAborted) : null;

    public static IResult Unauthorized() => Error(StatusCodes.Status401Unauthorized, "unauthorized");

    public static IResult Error(int status, params string[] codes) =>
        Results.Json(new { code = codes[0], codes }, Json, statusCode: status);

    public static IResult Error(int status, IReadOnlyList<string> codes) => Error(status, codes.ToArray());

    public static IResult InvalidRequest() => Error(StatusCodes.Status400BadRequest, "invalid_request");

    public static AmountMode? ParseAmountMode(string? id) => id switch
    {
        "integer" => AmountMode.Integer,
        "two_decimals" => AmountMode.TwoDecimals,
        _ => null,
    };

    public static QuantityMode? ParseQuantityMode(string? id) => id switch
    {
        "integer" => QuantityMode.Integer,
        "fractional" => QuantityMode.Fractional,
        _ => null,
    };
}
