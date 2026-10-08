using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;

namespace Pulperia.Domain.Catalog;

/// <summary>Campo de un producto al que se refiere un problema de validación.</summary>
public enum ProductField
{
    Name,
    Price,
    Unit,
}

/// <param name="Code">Código estable, el mismo del móvil y de la API.</param>
public sealed record ProductIssue(ProductField Field, string Code);

public abstract record ProductValidationResult;

/// <param name="Name">El nombre, sin espacios exteriores.</param>
public sealed record ValidProduct(string Name, Money Price, SaleUnit Unit) : ProductValidationResult;

public sealed record InvalidProduct(IReadOnlyList<ProductIssue> Issues) : ProductValidationResult;

public static class ProductValidator
{
    /// <summary>
    /// Valida un producto del catálogo (RF-24): lleva nombre, un precio positivo y, con
    /// montos enteros, sin centavos (RF-36), y una unidad de la lista compartida (RF-86);
    /// sin unidad indicada se usa la de omisión. Reporta todos los problemas: nombre,
    /// precio y unidad.
    /// </summary>
    public static ProductValidationResult Validate(
        string name, Money price, AmountMode amountMode, string? unitId = null)
    {
        var issues = new List<ProductIssue>();

        var trimmed = name.Trim();
        if (trimmed.Length == 0)
        {
            issues.Add(new ProductIssue(ProductField.Name, "product_name_required"));
        }

        var priceError = AmountRules.Error(price, amountMode);
        if (priceError is not null)
        {
            issues.Add(new ProductIssue(ProductField.Price, priceError.Value.Code()));
        }

        var unit = SaleUnits.Default;
        if (unitId is not null)
        {
            var parsed = SaleUnits.TryFromId(unitId);
            if (parsed is null)
            {
                issues.Add(new ProductIssue(ProductField.Unit, "product_unit_unknown"));
            }
            else
            {
                unit = parsed.Value;
            }
        }

        return issues.Count == 0 ? new ValidProduct(trimmed, price, unit) : new InvalidProduct(issues);
    }
}
