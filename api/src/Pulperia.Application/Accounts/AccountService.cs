using Pulperia.Domain.Access;
using Pulperia.Domain.Accounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Invitations;

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

    /// <summary>
    /// Crea la cuenta de quien solo viene a trabajar con un código de invitación (RF-105, RF-106, D-32):
    /// sin negocio propio, como empleado del negocio de la invitación. Todo o nada: con un código que
    /// no sirve, o un correo ya registrado, no se crea la cuenta ni se consume el código.
    /// </summary>
    public async Task<AccountResult<RegisteredAccount>> RegisterWithInvitationCodeAsync(
        string? email, string? password, string? typedCode, CancellationToken cancellationToken = default)
    {
        var problems = new List<string>();
        if (!AccountRules.IsValidEmail(AccountRules.NormalizeEmail(email)))
        {
            problems.Add("email_invalid");
        }
        if (AccountRules.PasswordError(password) is { } passwordError)
        {
            problems.Add(passwordError);
        }
        if (problems.Count > 0)
        {
            return AccountResult<RegisteredAccount>.Fail(problems);
        }
        if (InvitationCodes.Normalize(typedCode) is not { } code)
        {
            return AccountResult<RegisteredAccount>.Fail("invalid_invitation_code");
        }

        var account = new NewInvitedAccount(
            Guid.CreateVersion7(),
            AccountRules.NormalizeEmail(email),
            hasher.Hash(password!),
            code,
            clock.GetUtcNow().UtcDateTime);
        var outcome = await store.TryCreateInvitedAccountAsync(account, cancellationToken);
        return outcome.Status switch
        {
            InvitedAccountStatus.Created => AccountResult<RegisteredAccount>.Ok(
                new RegisteredAccount(account.UserId, outcome.BusinessId)),
            InvitedAccountStatus.EmailTaken => AccountResult<RegisteredAccount>.Fail("email_taken"),
            _ => AccountResult<RegisteredAccount>.Fail("invalid_invitation_code"),
        };
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
        // Solo quien sabe la contraseña se entera de que la cuenta está suspendida (RF-99).
        if (user.IsSuspended)
        {
            return AccountResult<AuthTokens>.Fail("account_suspended");
        }
        if (check.NeedsRehash)
        {
            await store.UpdatePasswordHashAsync(user.Id, hasher.Hash(password!), cancellationToken);
        }

        var now = clock.GetUtcNow();
        var refreshLifetime = await RefreshLifetimeAsync(user.Id, cancellationToken);
        var accessToken = TokenSecrets.NewToken();
        var refreshToken = TokenSecrets.NewToken();
        await store.AddSessionAsync(
            new NewSession(
                Guid.CreateVersion7(), user.Id,
                TokenSecrets.Hash(accessToken), (now + SessionLifetimes.Access).UtcDateTime,
                TokenSecrets.Hash(refreshToken), (now + refreshLifetime).UtcDateTime,
                now.UtcDateTime),
            cancellationToken);
        return AccountResult<AuthTokens>.Ok(new AuthTokens(
            user.Id, accessToken, now + SessionLifetimes.Access, refreshToken, now + refreshLifetime));
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

        var refreshLifetime = await RefreshLifetimeAsync(session.UserId, cancellationToken);
        var newAccess = TokenSecrets.NewToken();
        var newRefresh = TokenSecrets.NewToken();
        var rotated = await store.RotateSessionAsync(
            session.Id, oldHash,
            TokenSecrets.Hash(newAccess), (now + SessionLifetimes.Access).UtcDateTime,
            TokenSecrets.Hash(newRefresh), (now + refreshLifetime).UtcDateTime,
            cancellationToken);
        return rotated
            ? AccountResult<AuthTokens>.Ok(new AuthTokens(
                session.UserId, newAccess, now + SessionLifetimes.Access, newRefresh, now + refreshLifetime))
            : AccountResult<AuthTokens>.Fail("invalid_refresh_token");
    }

    /// <summary>
    /// Cuánto dura la renovación de esta cuenta: la de un super administrador es corta (D-29) y se
    /// decide cada vez, así que marcar a alguien acorta sus sesiones al renovarlas.
    /// </summary>
    private async Task<TimeSpan> RefreshLifetimeAsync(Guid userId, CancellationToken cancellationToken) =>
        await store.IsActiveSuperAdminAsync(userId, cancellationToken)
            ? SessionLifetimes.SuperAdminRefresh
            : SessionLifetimes.Refresh;

    /// <summary>Si la cuenta es hoy un super administrador sin suspender (RF-96, D-29). Lo exige cada petición de /api/admin.</summary>
    public Task<bool> IsActiveSuperAdminAsync(Guid userId, CancellationToken cancellationToken = default) =>
        store.IsActiveSuperAdminAsync(userId, cancellationToken);

    /// <summary>
    /// Si el negocio puede atender peticiones: null si está activo, o el código con el que rechaza
    /// (<c>business_pending</c>, <c>business_suspended</c>). Se mira después de comprobar la
    /// pertenencia, para no revelar el estado de un negocio a quien no es de él (D-29, D-30).
    /// </summary>
    public async Task<string?> CheckBusinessAvailableAsync(Guid businessId, CancellationToken cancellationToken = default) =>
        (await store.FindBusinessStatusAsync(businessId, cancellationToken))?.RejectionCode();

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

    /// <summary>Crea un negocio nuevo y asigna al usuario como dueño (RF-7, RF-78, RF-79).</summary>
    public async Task<AccountResult<BusinessSummary>> CreateBusinessAsync(
        Guid userId, string? name, AmountMode amountMode, QuantityMode quantityMode,
        CancellationToken cancellationToken = default)
    {
        if (AccountRules.BusinessNameError(name) is { } problem)
        {
            return AccountResult<BusinessSummary>.Fail(problem);
        }

        // Quien ya es dueño de un negocio activo crea los demás activos; quien no, pendientes (RF-104, D-30).
        var status = await store.OwnsActiveBusinessAsync(userId, cancellationToken)
            ? BusinessStatus.Active
            : BusinessStatus.Pending;
        var business = new NewBusiness(
            Guid.CreateVersion7(), userId, name!.Trim(), amountMode, quantityMode, clock.GetUtcNow().UtcDateTime, status);
        await store.AddBusinessAsync(business, cancellationToken);
        return AccountResult<BusinessSummary>.Ok(
            new BusinessSummary(business.BusinessId, business.Name, Role.Owner, amountMode, quantityMode, status));
    }

    /// <summary>Los negocios del usuario con su rol en cada uno, ordenados por nombre (RF-5, RF-6).</summary>
    public async Task<IReadOnlyList<BusinessSummary>> ListBusinessesAsync(
        Guid userId, CancellationToken cancellationToken = default) =>
        (await store.ListBusinessesAsync(userId, cancellationToken))
            .OrderBy(b => b.Name, StringComparer.OrdinalIgnoreCase)
            .ThenBy(b => b.Id)
            .ToList();

    /// <summary>
    /// El rol del usuario en el negocio, o null si no tiene una pertenencia activa en él (RF-6, RF-50).
    /// Lo exige cada petición a un negocio.
    /// </summary>
    public Task<Role?> AuthorizeBusinessAsync(
        Guid userId, Guid businessId, CancellationToken cancellationToken = default) =>
        store.FindActiveRoleAsync(userId, businessId, cancellationToken);
}
