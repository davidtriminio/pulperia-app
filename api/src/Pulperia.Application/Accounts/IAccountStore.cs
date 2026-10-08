using Pulperia.Domain.Business;

namespace Pulperia.Application.Accounts;

/// <summary>Una cuenta nueva con su primer negocio, que se guarda entera o no se guarda.</summary>
public sealed record NewAccount(
    Guid UserId,
    string Email,
    string PasswordHash,
    Guid BusinessId,
    string BusinessName,
    AmountMode AmountMode,
    QuantityMode QuantityMode,
    DateTime CreatedAt);

/// <summary>
/// Lo que el servicio de cuentas necesita de la base de datos. Las cuentas, los negocios y las
/// sesiones no están limitados a un negocio: son anteriores a elegir uno.
/// </summary>
public interface IAccountStore
{
    /// <summary>
    /// Crea el usuario, el negocio y la pertenencia de dueño en una sola transacción. Devuelve
    /// false, sin crear nada, si el correo ya está registrado.
    /// </summary>
    Task<bool> TryCreateAccountAsync(NewAccount account, CancellationToken cancellationToken = default);

    Task<UserCredentials?> FindUserByEmailAsync(string normalizedEmail, CancellationToken cancellationToken = default);

    Task UpdatePasswordHashAsync(Guid userId, string passwordHash, CancellationToken cancellationToken = default);

    Task AddSessionAsync(NewSession session, CancellationToken cancellationToken = default);

    Task<SessionInfo?> FindSessionByAccessHashAsync(string accessTokenHash, CancellationToken cancellationToken = default);

    Task<SessionInfo?> FindSessionByRefreshHashAsync(string refreshTokenHash, CancellationToken cancellationToken = default);

    /// <summary>
    /// Reemplaza los dos tokens de la sesión, pero solo si sigue abierta y su token de renovación
    /// es todavía <paramref name="oldRefreshHash"/>. Es atómico: de dos renovaciones simultáneas
    /// con el mismo token solo una devuelve true.
    /// </summary>
    Task<bool> RotateSessionAsync(
        Guid sessionId,
        string oldRefreshHash,
        string newAccessHash,
        DateTime accessExpiresAt,
        string newRefreshHash,
        DateTime refreshExpiresAt,
        CancellationToken cancellationToken = default);

    /// <summary>Cierra la sesión si sigue abierta; si ya estaba cerrada no cambia nada.</summary>
    Task RevokeSessionAsync(Guid sessionId, DateTime at, CancellationToken cancellationToken = default);
}
