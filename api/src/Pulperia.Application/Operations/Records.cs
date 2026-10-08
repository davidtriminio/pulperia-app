using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Quantities;

namespace Pulperia.Application.Operations;

/// <summary>Un cliente tal como lo guarda el servidor (RF-14, RF-73).</summary>
public sealed record ClientRecord(
    Guid Id,
    string Name,
    string CharacterId,
    string SkinId,
    string BackgroundId,
    string? Phone,
    string? Address,
    string? Note,
    bool Archived,
    int Version,
    Guid CreatedBy,
    DateTime CreatedAt,
    DateTime UpdatedAt);

/// <summary>Un producto del catálogo; guarda solo el último precio anterior (RF-90, D-24).</summary>
public sealed record ProductRecord(
    Guid Id,
    string Name,
    Money Price,
    SaleUnit Unit,
    Money? PreviousPrice,
    DateTime? PriceChangedAt,
    bool Archived,
    int Version,
    Guid CreatedBy,
    DateTime CreatedAt);

/// <summary>Los modos de montos y cantidades vigentes del negocio (RF-7, RF-8, RF-9).</summary>
public sealed record BusinessModes(AmountMode Amount, QuantityMode Quantity);

/// <summary>Un ítem de fiado: copia el precio y la unidad del momento de la compra (principio 4, RF-88).</summary>
public sealed record FiadoItemRecord(
    Guid Id,
    Guid? ProductId,
    string Description,
    Quantity Quantity,
    SaleUnit Unit,
    Money UnitPrice,
    Money Subtotal);

/// <summary>Un fiado con sus ítems (ninguno si se registró solo con monto, RF-29).</summary>
public sealed record FiadoRecord(
    Guid Id,
    Guid ClientId,
    Money Total,
    DateTime OccurredAt,
    Guid CreatedBy,
    DateTime? AnnulledAt,
    Guid? AnnulledBy,
    IReadOnlyList<FiadoItemRecord> Items);
