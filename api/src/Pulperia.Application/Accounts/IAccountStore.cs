using Pulperia.Domain.Access;
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

/// <summary>Una cuenta nueva que entra a un negocio existente con un código de invitación (D-32).</summary>
public sealed record NewInvitedAccount(
    Guid UserId,
    string Email,
    string PasswordHash,
    string Code,
    DateTime CreatedAt);

/// <summary>Cómo terminó el registro con código: lo que se creó, o por qué no se creó nada.</summary>
public enum InvitedAccountStatus
{
    Created,
    EmailTaken,
    InvalidCode,
}

public sealed record InvitedAccountOutcome(InvitedAccountStatus Status, Guid BusinessId = default);

/// <summary>Un negocio adicional de un usuario ya registrado, que lo crea como dueño.</summary>
public sealed record NewBusiness(
    Guid BusinessId,
    Guid OwnerId,
    string Name,
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

    /// <summary>
    /// Crea el usuario y su pertenencia de empleado al negocio de la invitación pendiente con ese
    /// código, y la marca aceptada, todo en una sola transacción (D-32). Si el código no está
    /// pendiente o el correo ya existe no crea ni consume nada.
    /// </summary>
    Task<InvitedAccountOutcome> TryCreateInvitedAccountAsync(
        NewInvitedAccount account, CancellationToken cancellationToken = default);

    /// <summary>
    /// Si la cuenta está marcada como super administrador y no está suspendida (D-29). Se consulta
    /// en cada petición de administración y al abrir o renovar una sesión.
    /// </summary>
    Task<bool> IsActiveSuperAdminAsync(Guid userId, CancellationToken cancellationToken = default);

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

    /// <summary>Crea el negocio y la pertenencia de dueño en una sola transacción (RF-79).</summary>
    Task AddBusinessAsync(NewBusiness business, CancellationToken cancellationToken = default);

    /// <summary>Los negocios en los que el usuario tiene una pertenencia activa, con su rol.</summary>
    Task<IReadOnlyList<BusinessSummary>> ListBusinessesAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>El estado del negocio (D-30); null si no existe.</summary>
    Task<BusinessStatus?> FindBusinessStatusAsync(Guid businessId, CancellationToken cancellationToken = default);

    /// <summary>El rol del usuario en el negocio si su pertenencia está activa; null si no pertenece o fue removido.</summary>
    Task<Role?> FindActiveRoleAsync(Guid userId, Guid businessId, CancellationToken cancellationToken = default);
}
