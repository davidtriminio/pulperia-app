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
