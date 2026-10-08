using Pulperia.Domain.Accounts;

namespace Pulperia.Application.Accounts;

/// <summary>Cuentas, negocios y sesiones. Cada rechazo lleva un código estable (RNF-5).</summary>
public sealed class AccountService(IAccountStore store, PasswordHasher hasher, TimeProvider clock)
{
    /// <summary>Crea la cuenta con su primer negocio y la asigna a él como dueño (RF-1, RF-2, RF-7, RF-78).</summary>
    public async Task<AccountResult<RegisteredAccount>> RegisterAsync(
        RegisterRequest request, CancellationToken cancellationToken = default)
    {
        var problems = AccountRules.ValidateRegistration(request.Email, request.Password, request.BusinessName);
        if (problems.Count > 0)
        {
            return AccountResult<RegisteredAccount>.Fail(problems);
        }

        var account = new NewAccount(
            Guid.CreateVersion7(),
            AccountRules.NormalizeEmail(request.Email),
            hasher.Hash(request.Password),
            Guid.CreateVersion7(),
            request.BusinessName.Trim(),
            request.AmountMode,
            request.QuantityMode,
            clock.GetUtcNow().UtcDateTime);

        return await store.TryCreateAccountAsync(account, cancellationToken)
            ? AccountResult<RegisteredAccount>.Ok(new RegisteredAccount(account.UserId, account.BusinessId))
            : AccountResult<RegisteredAccount>.Fail("email_taken");
    }

    private readonly Lazy<string> _unknownUserHash = new(() => hasher.Hash("sin-usuario"));

    /// <summary>
    /// Inicia una sesión con correo y contraseña (RF-3). Un correo desconocido y una contraseña
    /// errónea dan el mismo rechazo, y ambos hacen el mismo trabajo de hash.
    /// </summary>
    public async Task<AccountResult<AuthTokens>> LoginAsync(
        string email, string password, CancellationToken cancellationToken = default)
    {
        var user = await store.FindUserByEmailAsync(AccountRules.NormalizeEmail(email), cancellationToken);
        var check = hasher.Verify(user?.PasswordHash ?? _unknownUserHash.Value, password ?? "");
        if (user is null || !check.IsValid)
        {
            return AccountResult<AuthTokens>.Fail("invalid_credentials");
        }
        if (check.NeedsRehash)
        {
            await store.UpdatePasswordHashAsync(user.Id, hasher.Hash(password!), cancellationToken);
        }

        var now = clock.GetUtcNow();
        var accessToken = TokenSecrets.NewToken();
        var refreshToken = TokenSecrets.NewToken();
        await store.AddSessionAsync(
            new NewSession(
                Guid.CreateVersion7(), user.Id,
                TokenSecrets.Hash(accessToken), (now + SessionLifetimes.Access).UtcDateTime,
                TokenSecrets.Hash(refreshToken), (now + SessionLifetimes.Refresh).UtcDateTime,
                now.UtcDateTime),
            cancellationToken);
        return AccountResult<AuthTokens>.Ok(new AuthTokens(
            user.Id, accessToken, now + SessionLifetimes.Access, refreshToken, now + SessionLifetimes.Refresh));
    }

    /// <summary>
    /// Renueva la sesión (D-9): los dos tokens se reemplazan y el de renovación anterior deja de
    /// servir. Funciona aunque el de acceso ya haya caducado, mientras el de renovación no.
    /// </summary>
    public async Task<AccountResult<AuthTokens>> RefreshAsync(
        string refreshToken, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return AccountResult<AuthTokens>.Fail("invalid_refresh_token");
        }
        var oldHash = TokenSecrets.Hash(refreshToken);
        var now = clock.GetUtcNow();
        var session = await store.FindSessionByRefreshHashAsync(oldHash, cancellationToken);
        if (session is null || session.RevokedAt is not null || session.RefreshExpiresAt <= now.UtcDateTime)
        {
            return AccountResult<AuthTokens>.Fail("invalid_refresh_token");
        }

        var newAccess = TokenSecrets.NewToken();
        var newRefresh = TokenSecrets.NewToken();
        var rotated = await store.RotateSessionAsync(
            session.Id, oldHash,
            TokenSecrets.Hash(newAccess), (now + SessionLifetimes.Access).UtcDateTime,
            TokenSecrets.Hash(newRefresh), (now + SessionLifetimes.Refresh).UtcDateTime,
            cancellationToken);
        return rotated
            ? AccountResult<AuthTokens>.Ok(new AuthTokens(
                session.UserId, newAccess, now + SessionLifetimes.Access, newRefresh, now + SessionLifetimes.Refresh))
            : AccountResult<AuthTokens>.Fail("invalid_refresh_token");
    }

    /// <summary>Cierra la sesión del token de acceso, aunque haya caducado. Cerrar dos veces no falla.</summary>
    public async Task LogoutAsync(string accessToken, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            return;
        }
        var session = await store.FindSessionByAccessHashAsync(TokenSecrets.Hash(accessToken), cancellationToken);
        if (session is { RevokedAt: null })
        {
            await store.RevokeSessionAsync(session.Id, clock.GetUtcNow().UtcDateTime, cancellationToken);
        }
    }

    /// <summary>El usuario de un token de acceso vigente, o null si no existe, caducó o se cerró la sesión.</summary>
    public async Task<AuthenticatedUser?> AuthenticateAsync(
        string accessToken, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            return null;
        }
        var session = await store.FindSessionByAccessHashAsync(TokenSecrets.Hash(accessToken), cancellationToken);
        return session is not null && session.RevokedAt is null && session.AccessExpiresAt > clock.GetUtcNow().UtcDateTime
            ? new AuthenticatedUser(session.UserId, session.Id)
            : null;
    }
}
