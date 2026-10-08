using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Quantities;

namespace Pulperia.Domain.Ledger;

/// <summary>
/// Subtotal de un ítem: cantidad por precio unitario, redondeado según el modo de
/// montos del negocio con la mitad hacia arriba (RF-34, RF-83). Todo con aritmética
/// de enteros, sin decimales de punto flotante.
/// </summary>
public static class Subtotals
{
    private const long MilliPerUnit = 1000;
    private const long MinorUnitsPerLempira = 100;

    /// <summary>Subtotal según el modo de montos del negocio.</summary>
    public static Money Of(AmountMode mode, Quantity quantity, Money unitPrice) => mode switch
    {
        AmountMode.Integer => WholeLempira(quantity, unitPrice),
        AmountMode.TwoDecimals => Centavo(quantity, unitPrice),
        _ => throw new ArgumentOutOfRangeException(nameof(mode)),
    };

    /// <summary>
    /// Con montos enteros: redondeado al lempira entero más cercano, la mitad hacia
    /// arriba (RF-34).
    /// </summary>
    public static Money WholeLempira(Quantity quantity, Money unitPrice)
    {
        var exactMilliCents = ExactMilliCents(quantity, unitPrice);
        const long unitsPerWholeLempira = MilliPerUnit * MinorUnitsPerLempira;
        var lempiras = checked(exactMilliCents + unitsPerWholeLempira / 2) / unitsPerWholeLempira;
        return new Money(checked(lempiras * MinorUnitsPerLempira));
    }

    /// <summary>
    /// Con 2 decimales: redondeado al centavo más cercano, la mitad hacia arriba (RF-83).
    /// </summary>
    public static Money Centavo(Quantity quantity, Money unitPrice)
    {
        var exactMilliCents = ExactMilliCents(quantity, unitPrice);
        return new Money(checked(exactMilliCents + MilliPerUnit / 2) / MilliPerUnit);
    }

    /// <summary>Cantidad (milésimas) por precio (centavos): son milésimas de centavo.</summary>
    private static long ExactMilliCents(Quantity quantity, Money unitPrice)
    {
        if (quantity.Milli <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(quantity), "La cantidad debe ser positiva.");
        }
        if (!unitPrice.IsPositive)
        {
            throw new ArgumentOutOfRangeException(nameof(unitPrice), "El precio unitario debe ser positivo.");
        }
        return checked(quantity.Milli * unitPrice.MinorUnits);
    }
}
