namespace Pulperia.Domain.Ledger;

/// <summary>
/// Topes holgados que el servidor aplica a fiados y abonos como defensa contra desbordamientos y
/// datos absurdos (D-26). Están muy por encima de lo que cualquier pulpería registra, así que el
/// móvil no necesita validarlos: sus pantallas nunca llegan a esos valores.
/// </summary>
public static class LedgerLimits
{
    /// <summary>L 9,999,999.99 en la unidad menor: tope de un precio, un subtotal, un total o un abono.</summary>
    public const long MaxAmountMinorUnits = 999_999_999;

    /// <summary>1,000,000 en milésimas: tope de la cantidad de un ítem.</summary>
    public const long MaxQuantityMilli = 1_000_000_000;

    public const int MaxItemsPerFiado = 200;

    public const int MaxDescriptionLength = 200;

    public const string AmountTooLarge = "amount_too_large";
    public const string QuantityTooLarge = "quantity_too_large";
    public const string TooManyItems = "too_many_items";
    public const string DescriptionTooLong = "description_too_long";
}
