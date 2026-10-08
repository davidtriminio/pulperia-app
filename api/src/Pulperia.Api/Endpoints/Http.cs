using System.Text.Json;
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
