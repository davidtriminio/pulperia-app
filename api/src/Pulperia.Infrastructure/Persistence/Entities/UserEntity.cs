namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>Tabla <c>users</c>: una cuenta, identificada por su correo (RF-2).</summary>
public sealed class UserEntity
{
    public Guid Id { get; set; }

    /// <summary>Correo ya normalizado (sin espacios exteriores y en minúsculas): así es único sin distinguir mayúsculas.</summary>
    public string Email { get; set; } = "";

    public string PasswordHash { get; set; } = "";

    public DateTime CreatedAt { get; set; }
}
