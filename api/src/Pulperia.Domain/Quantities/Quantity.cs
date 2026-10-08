using System.Text.RegularExpressions;
using Pulperia.Domain.Business;

namespace Pulperia.Domain.Quantities;

/// <summary>Motivo por el que se rechaza una cantidad ingresada.</summary>
public enum QuantityError
{
    NotPositive,
    NotWhole,
    TooManyDecimals,
    InvalidFormat,
}

public static class QuantityErrors
{
    /// <summary>Código estable, el mismo de los vectores compartidos.</summary>
    public static string Code(this QuantityError error) => error switch
    {
        QuantityError.NotPositive => "quantity_not_positive",
        QuantityError.NotWhole => "quantity_not_whole",
        QuantityError.TooManyDecimals => "quantity_too_many_decimals",
        QuantityError.InvalidFormat => "quantity_invalid_format",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

/// <summary>Resultado de leer una cantidad: o una <see cref="Quantities.Quantity"/> válida o un error.</summary>
public readonly record struct QuantityParseResult(Quantity? Quantity, QuantityError? Error)
{
    public bool IsValid => Quantity is not null;

    public static QuantityParseResult Ok(Quantity quantity) => new(quantity, null);

    public static QuantityParseResult Fail(QuantityError error) => new(null, error);
}

/// <summary>
/// Cantidad exacta, guardada como entero en milésimas (0.25 es 250). Nunca usa
/// decimales de punto flotante.
/// </summary>
public readonly record struct Quantity(long Milli)
{
    private const int MilliPerUnit = 1000;
    private const int MaxDecimals = 3;

    // \z y no $: en .NET $ también acepta un salto de línea final. [0-9] y no \d.
    private static readonly Regex PlainDecimal =
        new(@"^(-?)([0-9]+)(?:\.([0-9]+))?\z", RegexOptions.CultureInvariant);

    public bool IsWhole => Milli % MilliPerUnit == 0;

    /// <summary>
    /// Lee el texto que escribió el usuario (punto decimal, sin separadores de miles)
    /// según el modo de cantidades del negocio. Un número demasiado grande para
    /// guardarse se rechaza como formato inválido.
    /// </summary>
    public static QuantityParseResult Parse(string text, QuantityMode mode)
    {
        var match = PlainDecimal.Match(text);
        if (!match.Success)
        {
            return QuantityParseResult.Fail(QuantityError.InvalidFormat);
        }

        var negative = match.Groups[1].Value == "-";
        var whole = match.Groups[2].Value;
        var fraction = match.Groups[3].Success ? match.Groups[3].Value : string.Empty;

        var isZero = (whole + fraction).All(c => c == '0');
        if (negative || isZero)
        {
            return QuantityParseResult.Fail(QuantityError.NotPositive);
        }

        var hasFraction = fraction.Any(c => c != '0');
        switch (mode)
        {
            case QuantityMode.Integer:
                if (hasFraction)
                {
                    return QuantityParseResult.Fail(QuantityError.NotWhole);
                }
                break;
            case QuantityMode.Fractional:
                if (fraction.Length > MaxDecimals)
                {
                    return QuantityParseResult.Fail(QuantityError.TooManyDecimals);
                }
                break;
        }

        var milliFraction = long.Parse(fraction.PadRight(MaxDecimals, '0')[..MaxDecimals]);
        if (!long.TryParse(whole, out var units) || units > (long.MaxValue - milliFraction) / MilliPerUnit)
        {
            return QuantityParseResult.Fail(QuantityError.InvalidFormat);
        }

        return QuantityParseResult.Ok(new Quantity(units * MilliPerUnit + milliFraction));
    }
}
