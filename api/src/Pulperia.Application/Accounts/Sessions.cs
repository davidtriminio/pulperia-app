using System.Security.Cryptography;
using System.Text;

namespace Pulperia.Application.Accounts;

/// <summary>Los tokens de una sesión, tal como se entregan al dispositivo (D-9, D-27).</summary>
public sealed record AuthTokens(
    Guid UserId,
    string AccessToken,
    DateTimeOffset AccessExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshExpiresAt);

/// <summary>Quién está detrás de un token de acceso válido.</summary>
public sealed record AuthenticatedUser(Guid UserId, Guid SessionId);

/// <summary>Duraciones del plan (D-27): acceso corto y renovación larga.</summary>
public static class SessionLifetimes
{
    public static readonly TimeSpan Access = TimeSpan.FromMinutes(15);
    public static readonly TimeSpan Refresh = TimeSpan.FromDays(90);

    /// <summary>La renovación de un super administrador es mucho más corta (RF-96, D-29).</summary>
    public static readonly TimeSpan SuperAdminRefresh = TimeSpan.FromHours(12);
}

/// <summary>Tokens opacos: 32 bytes aleatorios en base64url; en la base solo vive su hash SHA-256.</summary>
internal static class TokenSecrets
{
    public static string NewToken() => Base64Url(RandomNumberGenerator.GetBytes(32));

    public static string Hash(string token) => Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}

public sealed record UserCredentials(Guid Id, string PasswordHash);

public sealed record NewSession(
    Guid Id,
    Guid UserId,
    string AccessTokenHash,
    DateTime AccessExpiresAt,
    string RefreshTokenHash,
    DateTime RefreshExpiresAt,
    DateTime CreatedAt);

public sealed record SessionInfo(
    Guid Id,
    Guid UserId,
    DateTime AccessExpiresAt,
    DateTime RefreshExpiresAt,
    DateTime? RevokedAt);
