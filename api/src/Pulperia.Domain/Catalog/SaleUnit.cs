namespace Pulperia.Domain.Catalog;

/// <summary>
/// Unidad de venta de un producto o de un ítem de fiado (RF-86 a RF-89). Es solo una
/// etiqueta: el precio unitario es por esa unidad y la cantidad se expresa en ella,
/// sin convertir entre unidades ni cambiar ningún cálculo. Debe coincidir con
/// <c>shared/vectors/units.json</c>.
/// </summary>
public enum SaleUnit
{
    Unit,
    Pound,
    Ounce,
    Kilo,
    Dozen,
    Liter,
    Gallon,
    Box,
    Bag,
    Pack,
}

public static class SaleUnits
{
    /// <summary>La unidad de lo que no indica otra (RF-86, RF-87).</summary>
    public const SaleUnit Default = SaleUnit.Unit;

    /// <summary>
    /// Identificador estable, el mismo de los datos compartidos y de la API. Los ids
    /// nunca se renombran ni se reutilizan, porque se guardan en cada producto e ítem.
    /// </summary>
    public static string Id(this SaleUnit unit) => unit switch
    {
        SaleUnit.Unit => "unit",
        SaleUnit.Pound => "pound",
        SaleUnit.Ounce => "ounce",
        SaleUnit.Kilo => "kilo",
        SaleUnit.Dozen => "dozen",
        SaleUnit.Liter => "liter",
        SaleUnit.Gallon => "gallon",
        SaleUnit.Box => "box",
        SaleUnit.Bag => "bag",
        SaleUnit.Pack => "pack",
        _ => throw new ArgumentOutOfRangeException(nameof(unit)),
    };

    /// <summary>La unidad con ese id, o null si no existe en la lista.</summary>
    public static SaleUnit? TryFromId(string? id) =>
        Enum.GetValues<SaleUnit>().Cast<SaleUnit?>().FirstOrDefault(u => u!.Value.Id() == id);

    public static bool IsValidId(string? id) => TryFromId(id) is not null;
}
