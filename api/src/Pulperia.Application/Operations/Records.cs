using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;

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
