using Pulperia.Domain.Amounts;

namespace Pulperia.Domain.Catalog;

/// <summary>
/// El precio anterior de un producto y cuándo cambió (RF-90, D-24). Es solo el último
/// anterior, no un historial: cada cambio de precio reemplaza al guardado. Ambos son
/// nulos mientras el precio nunca ha cambiado.
/// </summary>
/// <param name="ChangedAt">Fecha del cambio, en UTC.</param>
public readonly record struct PriceHistory(Money? PreviousPrice = null, DateTime? ChangedAt = null);

public static class PriceChanges
{
    /// <summary>
    /// Lo que guarda un producto tras cambiarle el precio de <paramref name="currentPrice"/> a
    /// <paramref name="newPrice"/> en la fecha <paramref name="at"/> (la de creación de la
    /// operación). Un precio distinto deja el vigente como anterior y <paramref name="at"/> como
    /// fecha, sustituyendo lo que hubiera; un precio igual (por ejemplo cuando solo cambia el
    /// nombre o la unidad) no toca nada y devuelve <paramref name="current"/>. Debe dar lo mismo
    /// que <c>shared/vectors/price-change.json</c> y que el móvil.
    /// </summary>
    public static PriceHistory Apply(Money currentPrice, PriceHistory current, Money newPrice, DateTimeOffset at) =>
        newPrice == currentPrice
            ? current
            : new PriceHistory(currentPrice, at.UtcDateTime);
}
