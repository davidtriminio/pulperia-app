using Pulperia.Application.Operations;
using Pulperia.Application.Sync;
using Pulperia.Domain.Catalog;

namespace Pulperia.Api.Endpoints;

/// <summary>
/// La forma en JSON de los registros de negocio, una sola para la sincronización y las
/// consultas (el contrato de <c>shared/openapi.json</c>). Dinero en la unidad menor, cantidades
/// en milésimas, fechas en UTC y nombres en camelCase.
/// </summary>
internal static class EntityJson
{
    public static Dictionary<string, object?> Client(ClientRecord c) => new()
    {
        ["id"] = c.Id, ["name"] = c.Name, ["characterId"] = c.CharacterId, ["skinId"] = c.SkinId,
        ["backgroundId"] = c.BackgroundId, ["phone"] = c.Phone, ["address"] = c.Address, ["note"] = c.Note,
        ["archived"] = c.Archived, ["version"] = c.Version, ["createdBy"] = c.CreatedBy,
        ["createdAt"] = c.CreatedAt, ["updatedAt"] = c.UpdatedAt,
    };

    public static Dictionary<string, object?> Product(ProductRecord p) => new()
    {
        ["id"] = p.Id, ["name"] = p.Name, ["price"] = p.Price.MinorUnits, ["unit"] = p.Unit.Id(),
        ["previousPrice"] = p.PreviousPrice?.MinorUnits, ["priceChangedAt"] = p.PriceChangedAt,
        ["archived"] = p.Archived, ["version"] = p.Version, ["createdBy"] = p.CreatedBy, ["createdAt"] = p.CreatedAt,
    };

    public static object Item(FiadoItemRecord i) => new
    {
        id = i.Id, productId = i.ProductId, description = i.Description, quantity = i.Quantity.Milli,
        unit = i.Unit.Id(), unitPrice = i.UnitPrice.MinorUnits, subtotal = i.Subtotal.MinorUnits,
    };

    public static Dictionary<string, object?> Fiado(FiadoRecord f, long? serverSeq) => new()
    {
        ["id"] = f.Id, ["clientId"] = f.ClientId, ["total"] = f.Total.MinorUnits, ["occurredAt"] = f.OccurredAt,
        ["serverSeq"] = serverSeq, ["createdBy"] = f.CreatedBy, ["annulledAt"] = f.AnnulledAt,
        ["annulledBy"] = f.AnnulledBy, ["items"] = f.Items.Select(Item).ToList(),
    };

    public static Dictionary<string, object?> Payment(PaymentRecord p, long? serverSeq) => new()
    {
        ["id"] = p.Id, ["clientId"] = p.ClientId, ["amount"] = p.Amount.MinorUnits, ["occurredAt"] = p.OccurredAt,
        ["serverSeq"] = serverSeq, ["createdBy"] = p.CreatedBy, ["annulledAt"] = p.AnnulledAt, ["annulledBy"] = p.AnnulledBy,
    };

    /// <summary>La versión actual completa de un registro que cambió, tal como la recibe el móvil.</summary>
    public static object Of(ChangeEntry change) => change.Record switch
    {
        ClientRecord c => Client(c),
        ProductRecord p => Product(p),
        FiadoRecord f => Fiado(f, change.ArrivalSeq),
        PaymentRecord p => Payment(p, change.ArrivalSeq),
        _ => throw new ArgumentOutOfRangeException(nameof(change)),
    };
}
