using Pulperia.Domain.Catalog;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>products</c>: un producto del catálogo (RF-24). Nunca se borra: se archiva
/// (RF-27). Guarda solo el último precio anterior y la fecha del cambio (RF-90, D-24).
/// </summary>
public sealed class ProductEntity
{
    public Guid Id { get; set; }

    public Guid BusinessId { get; set; }

    public string Name { get; set; } = "";

    /// <summary>Precio en la unidad menor (centavos de lempira); siempre positivo.</summary>
    public long Price { get; set; }

    /// <summary>Unidad de venta de la lista compartida (RF-86); solo una etiqueta (RF-89).</summary>
    public SaleUnit Unit { get; set; } = SaleUnit.Unit;

    public long? PreviousPrice { get; set; }

    /// <summary>Fecha del último cambio de precio, en UTC; va junto con <see cref="PreviousPrice"/>.</summary>
    public DateTime? PriceChangedAt { get; set; }

    public bool Archived { get; set; }

    public int Version { get; set; } = 1;

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }
}
