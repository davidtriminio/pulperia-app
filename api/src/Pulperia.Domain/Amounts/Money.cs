using System.Text.RegularExpressions;
using Pulperia.Domain.Business;

namespace Pulperia.Domain.Amounts;

/// <summary>Motivo por el que se rechaza un monto ingresado.</summary>
public enum AmountError
{
    NotPositive,
    NotWhole,
    TooManyDecimals,
    InvalidFormat,
}

public static class AmountErrors
{
    /// <summary>Código estable, el mismo de los vectores compartidos.</summary>
    public static string Code(this AmountError error) => error switch
    {
        AmountError.NotPositive => "amount_not_positive",
        AmountError.NotWhole => "amount_not_whole",
        AmountError.TooManyDecimals => "amount_too_many_decimals",
        AmountError.InvalidFormat => "amount_invalid_format",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

/// <summary>Resultado de leer un monto: o un <see cref="Amounts.Money"/> válido o un error.</summary>
public readonly record struct MoneyParseResult(Money? Money, AmountError? Error)
{
    public bool IsValid => Money is not null;

    public static MoneyParseResult Ok(Money money) => new(money, null);

    public static MoneyParseResult Fail(AmountError error) => new(null, error);
}

/// <summary>
/// Monto de dinero exacto, guardado como entero en la unidad menor (centavos de
/// lempira). Nunca usa decimales de punto flotante. Puede ser negativo: un saldo
/// negativo es saldo a favor del cliente. Las operaciones desbordan con
/// excepción, nunca en silencio.
/// </summary>
public readonly record struct Money(long MinorUnits) : IComparable<Money>
{
    public static readonly Money Zero = new(0);

    private const int MinorUnitsPerLempira = 100;
    private const int MaxDecimals = 2;

    // \z y no $: en .NET $ también acepta un salto de línea final. [0-9] y no \d,
    // que aceptaría dígitos de otros alfabetos.
    private static readonly Regex PlainDecimal =
        new(@"^(-?)([0-9]+)(?:\.([0-9]+))?\z", RegexOptions.CultureInvariant);

    public bool IsZero => MinorUnits == 0;
    public bool IsPositive => MinorUnits > 0;
    public bool IsNegative => MinorUnits < 0;

    public static Money operator +(Money a, Money b) => new(checked(a.MinorUnits + b.MinorUnits));
    public static Money operator -(Money a, Money b) => new(checked(a.MinorUnits - b.MinorUnits));
    public static Money operator -(Money a) => new(checked(-a.MinorUnits));

    public static bool operator <(Money a, Money b) => a.MinorUnits < b.MinorUnits;
    public static bool operator <=(Money a, Money b) => a.MinorUnits <= b.MinorUnits;
    public static bool operator >(Money a, Money b) => a.MinorUnits > b.MinorUnits;
    public static bool operator >=(Money a, Money b) => a.MinorUnits >= b.MinorUnits;

    public int CompareTo(Money other) => MinorUnits.CompareTo(other.MinorUnits);

    /// <summary>
    /// Lee el texto que escribió el usuario (punto decimal, sin separadores de miles)
    /// según el modo de montos del negocio. Devuelve centavos de lempira. Un número
    /// demasiado grande para guardarse se rechaza como formato inválido.
    /// </summary>
    public static MoneyParseResult Parse(string text, AmountMode mode)
    {
        var match = PlainDecimal.Match(text);
        if (!match.Success)
        {
            return MoneyParseResult.Fail(AmountError.InvalidFormat);
        }

        var negative = match.Groups[1].Value == "-";
        var whole = match.Groups[2].Value;
        var fraction = match.Groups[3].Success ? match.Groups[3].Value : string.Empty;

        var isZero = (whole + fraction).All(c => c == '0');
        if (negative || isZero)
        {
            return MoneyParseResult.Fail(AmountError.NotPositive);
        }

        var hasFraction = fraction.Any(c => c != '0');
        switch (mode)
        {
            case AmountMode.Integer:
                if (hasFraction)
                {
                    return MoneyParseResult.Fail(AmountError.NotWhole);
                }
                break;
            case AmountMode.TwoDecimals:
                if (fraction.Length > MaxDecimals)
                {
                    return MoneyParseResult.Fail(AmountError.TooManyDecimals);
                }
                break;
        }

        var centavos = mode == AmountMode.Integer
            ? 0L
            : long.Parse(fraction.PadRight(MaxDecimals, '0'));
        if (!long.TryParse(whole, out var lempiras) || lempiras > (long.MaxValue - centavos) / MinorUnitsPerLempira)
        {
            return MoneyParseResult.Fail(AmountError.InvalidFormat);
        }

        return MoneyParseResult.Ok(new Money(lempiras * MinorUnitsPerLempira + centavos));
    }
}
