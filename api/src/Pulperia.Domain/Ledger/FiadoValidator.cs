using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Quantities;

namespace Pulperia.Domain.Ledger;

/// <summary>Un ítem de un fiado tal como lo ingresa el usuario.</summary>
/// <param name="ProductId">Producto del catálogo del que se copió el ítem; null si es un ítem libre.</param>
/// <param name="Unit">Unidad de venta del ítem (RF-87): la del producto o la que se le cambió; <c>unit</c> si es libre.</param>
public sealed record FiadoItemDraft(
    string Description,
    string? ProductId,
    Quantity Quantity,
    Money UnitPrice,
    SaleUnit Unit = SaleUnit.Unit);

/// <summary>
/// Lo que el usuario quiere registrar: un fiado con detalle de ítems o un fiado solo
/// con un monto total (RF-28, RF-29).
/// </summary>
public abstract record FiadoDraft;

public sealed record FiadoWithItems(IReadOnlyList<FiadoItemDraft> Items) : FiadoDraft;

/// <param name="Total">Null cuando el usuario no ha indicado ningún monto.</param>
public sealed record FiadoTotalOnly(Money? Total) : FiadoDraft;

/// <summary>Campo de un fiado al que se refiere un problema de validación.</summary>
public enum FiadoField
{
    Fiado,
    Total,
    Quantity,
    UnitPrice,
    Subtotal,
}

/// <param name="ItemIndex">Posición del ítem con el problema; null si no es de un ítem.</param>
/// <param name="Code">Código estable, el mismo del móvil y de los vectores compartidos.</param>
public sealed record FiadoIssue(int? ItemIndex, FiadoField Field, string Code);

public sealed record ValidFiadoItem(
    string Description,
    string? ProductId,
    Quantity Quantity,
    Money UnitPrice,
    SaleUnit Unit,
    Money Subtotal);

public abstract record FiadoValidationResult;

/// <summary>
/// Fiado válido. Con ítems, <paramref name="Total"/> es la suma de sus subtotales ya
/// redondeados; sin ítems, es el monto indicado.
/// </summary>
public sealed record ValidFiado(Money Total, IReadOnlyList<ValidFiadoItem> Items) : FiadoValidationResult;

public sealed record InvalidFiado(IReadOnlyList<FiadoIssue> Issues) : FiadoValidationResult;

public static class FiadoValidator
{
    private const string EmptyFiado = "fiado_empty";

    /// <summary>
    /// Valida un fiado según RF-28, RF-29, RF-32, RF-33, RF-34, RF-35, RF-36 y RF-83 y
    /// calcula los subtotales. Reporta todos los problemas, ítem por ítem y campo por campo.
    /// </summary>
    public static FiadoValidationResult Validate(
        FiadoDraft draft,
        AmountMode amountMode,
        QuantityMode quantityMode) => draft switch
    {
        FiadoTotalOnly t => ValidateTotalOnly(t.Total, amountMode),
        FiadoWithItems w => ValidateWithItems(w.Items, amountMode, quantityMode),
        _ => throw new ArgumentOutOfRangeException(nameof(draft)),
    };

    private static FiadoValidationResult ValidateTotalOnly(Money? total, AmountMode amountMode)
    {
        if (total is null)
        {
            return new InvalidFiado([new FiadoIssue(null, FiadoField.Fiado, EmptyFiado)]);
        }

        var error = AmountRules.Error(total.Value, amountMode);
        if (error is not null)
        {
            return new InvalidFiado([new FiadoIssue(null, FiadoField.Total, error.Value.Code())]);
        }
        return new ValidFiado(total.Value, []);
    }

    private static FiadoValidationResult ValidateWithItems(
        IReadOnlyList<FiadoItemDraft> items,
        AmountMode amountMode,
        QuantityMode quantityMode)
    {
        if (items.Count == 0)
        {
            return new InvalidFiado([new FiadoIssue(null, FiadoField.Fiado, EmptyFiado)]);
        }

        var issues = new List<FiadoIssue>();
        var valid = new List<ValidFiadoItem>();
        for (var i = 0; i < items.Count; i++)
        {
            var item = items[i];
            var quantityError = QuantityError(item.Quantity, quantityMode);
            var priceError = AmountRules.Error(item.UnitPrice, amountMode);
            if (quantityError is not null)
            {
                issues.Add(new FiadoIssue(i, FiadoField.Quantity, quantityError.Value.Code()));
            }
            if (priceError is not null)
            {
                issues.Add(new FiadoIssue(i, FiadoField.UnitPrice, priceError.Value.Code()));
            }
            if (quantityError is not null || priceError is not null)
            {
                continue;
            }

            var subtotal = Subtotals.Of(amountMode, item.Quantity, item.UnitPrice);
            if (!subtotal.IsPositive)
            {
                issues.Add(new FiadoIssue(i, FiadoField.Subtotal, AmountError.NotPositive.Code()));
                continue;
            }

            valid.Add(new ValidFiadoItem(
                item.Description, item.ProductId, item.Quantity, item.UnitPrice, item.Unit, subtotal));
        }

        if (issues.Count > 0)
        {
            return new InvalidFiado(issues);
        }

        var total = valid.Aggregate(Money.Zero, (sum, item) => sum + item.Subtotal);
        return new ValidFiado(total, valid);
    }

    private static QuantityError? QuantityError(Quantity quantity, QuantityMode mode)
    {
        if (quantity.Milli <= 0)
        {
            return Quantities.QuantityError.NotPositive;
        }
        if (mode == QuantityMode.Integer && !quantity.IsWhole)
        {
            return Quantities.QuantityError.NotWhole;
        }
        return null;
    }
}
