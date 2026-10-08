namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>clients</c>: un cliente al que se le fía (RF-14). Nunca se borra: se archiva
/// (RF-20). <see cref="Version"/> sube con cada edición para detectar conflictos (D-8).
/// </summary>
public sealed class ClientEntity
{
    public Guid Id { get; set; }

    public Guid BusinessId { get; set; }

    public string Name { get; set; } = "";

    /// <summary>Los tres componentes del avatar, ids de la paleta compartida (RF-14, RF-72).</summary>
    public string CharacterId { get; set; } = "";

    public string SkinId { get; set; } = "";

    public string BackgroundId { get; set; } = "";

    public string? Phone { get; set; }

    public string? Address { get; set; }

    public string? Note { get; set; }

    public bool Archived { get; set; }

    public int Version { get; set; } = 1;

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }
}
