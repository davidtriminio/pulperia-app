namespace Pulperia.Infrastructure.Persistence.Entities;

/// <summary>Tabla <c>users</c>: una cuenta, identificada por su correo (RF-2).</summary>
public sealed class UserEntity
{
    public Guid Id { get; set; }

    /// <summary>Correo ya normalizado (sin espacios exteriores y en minúsculas): así es único sin distinguir mayúsculas.</summary>
    public string Email { get; set; } = "";

    public string PasswordHash { get; set; } = "";

    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// Administra la plataforma (D-29). Solo cambia con los comandos del servidor; la base no deja
    /// retirarla al último.
    /// </summary>
    public bool IsSuperAdmin { get; set; }

    /// <summary>Desde cuándo la cuenta está suspendida (RF-99); null si no lo está.</summary>
    public DateTime? SuspendedAt { get; set; }

    public string? SuspensionReason { get; set; }
}
