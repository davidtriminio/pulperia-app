namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>
/// Tabla <c>sessions</c>: una sesión de un dispositivo (D-9, D-27). Guarda solo el hash SHA-256
/// (base64) de sus dos tokens, nunca los tokens.
/// </summary>
public sealed class SessionEntity
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string AccessTokenHash { get; set; } = "";

    public DateTime AccessExpiresAt { get; set; }

    public string RefreshTokenHash { get; set; } = "";

    public DateTime RefreshExpiresAt { get; set; }

    public DateTime CreatedAt { get; set; }

    /// <summary>Cuándo se cerró la sesión; null mientras siga abierta.</summary>
    public DateTime? RevokedAt { get; set; }
}
