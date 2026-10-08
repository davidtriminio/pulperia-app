using Pulperia.Domain.Catalog;

namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>fiado_items</c>: un ítem de un fiado, con la descripción, cantidad, unidad y
/// precio unitario del momento de la compra (RF-28, RF-88; principio 4). Lleva
/// <c>business_id</c> como el resto de las tablas de negocio, aunque el plan no lo liste.
/// </summary>
public sealed class FiadoItemEntity
{
    public Guid Id { get; set; }

    public Guid BusinessId { get; set; }

    public Guid FiadoId { get; set; }

    /// <summary>Producto del catálogo del que se copió; null en un ítem libre (RF-31).</summary>
    public Guid? ProductId { get; set; }

    public string Description { get; set; } = "";

    /// <summary>Cantidad en milésimas.</summary>
    public long Quantity { get; set; }

    public SaleUnit Unit { get; set; } = SaleUnit.Unit;

    /// <summary>Precio unitario en la unidad menor.</summary>
    public long UnitPrice { get; set; }

    /// <summary>Subtotal ya redondeado según el modo del negocio, en la unidad menor.</summary>
    public long Subtotal { get; set; }
}
