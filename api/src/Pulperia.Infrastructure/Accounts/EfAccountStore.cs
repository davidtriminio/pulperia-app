using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Accounts;

/// <summary>El almacén de cuentas sobre EF Core y PostgreSQL (D-25).</summary>
public sealed class EfAccountStore(PulperiaDbContext db) : IAccountStore
{
    private const string UniqueViolation = "23505";

    public async Task<bool> TryCreateAccountAsync(NewAccount account, CancellationToken cancellationToken = default)
    {
        db.Users.Add(new UserEntity
        {
            Id = account.UserId, Email = account.Email, PasswordHash = account.PasswordHash, CreatedAt = account.CreatedAt,
        });
        db.Businesses.Add(new BusinessEntity
        {
            Id = account.BusinessId, Name = account.BusinessName, AmountMode = account.AmountMode,
            QuantityMode = account.QuantityMode, CreatedAt = account.CreatedAt,
        });
        db.Memberships.Add(new MembershipEntity
        {
            UserId = account.UserId, BusinessId = account.BusinessId, Role = Role.Owner, Status = MembershipStatus.Active,
        });

        try
        {
            // Un solo guardado: usuario, negocio y pertenencia entran juntos o no entra ninguno.
            await db.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: UniqueViolation })
        {
            // Otro registro con el mismo correo ganó la carrera: el índice único es el árbitro.
            db.ChangeTracker.Clear();
            return false;
        }
    }

    public async Task<UserCredentials?> FindUserByEmailAsync(
        string normalizedEmail, CancellationToken cancellationToken = default) =>
        await db.Users.AsNoTracking().Where(u => u.Email == normalizedEmail)
            .Select(u => new UserCredentials(u.Id, u.PasswordHash))
            .SingleOrDefaultAsync(cancellationToken);

    public async Task UpdatePasswordHashAsync(
        Guid userId, string passwordHash, CancellationToken cancellationToken = default) =>
        await db.Users.Where(u => u.Id == userId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.PasswordHash, passwordHash), cancellationToken);

    public async Task AddSessionAsync(NewSession session, CancellationToken cancellationToken = default)
    {
        db.Sessions.Add(new SessionEntity
        {
            Id = session.Id, UserId = session.UserId,
            AccessTokenHash = session.AccessTokenHash, AccessExpiresAt = session.AccessExpiresAt,
            RefreshTokenHash = session.RefreshTokenHash, RefreshExpiresAt = session.RefreshExpiresAt,
            CreatedAt = session.CreatedAt,
        });
        await db.SaveChangesAsync(cancellationToken);
    }

    public async Task<SessionInfo?> FindSessionByAccessHashAsync(
        string accessTokenHash, CancellationToken cancellationToken = default) =>
        await db.Sessions.AsNoTracking().Where(s => s.AccessTokenHash == accessTokenHash)
            .Select(s => new SessionInfo(s.Id, s.UserId, s.AccessExpiresAt, s.RefreshExpiresAt, s.RevokedAt))
            .SingleOrDefaultAsync(cancellationToken);

    public async Task<SessionInfo?> FindSessionByRefreshHashAsync(
        string refreshTokenHash, CancellationToken cancellationToken = default) =>
        await db.Sessions.AsNoTracking().Where(s => s.RefreshTokenHash == refreshTokenHash)
            .Select(s => new SessionInfo(s.Id, s.UserId, s.AccessExpiresAt, s.RefreshExpiresAt, s.RevokedAt))
            .SingleOrDefaultAsync(cancellationToken);

    public async Task<bool> RotateSessionAsync(
        Guid sessionId, string oldRefreshHash, string newAccessHash, DateTime accessExpiresAt,
        string newRefreshHash, DateTime refreshExpiresAt, CancellationToken cancellationToken = default)
    {
        // Una sola sentencia condicional: la fila solo cambia si el token de renovación sigue siendo el viejo.
        var rows = await db.Sessions
            .Where(s => s.Id == sessionId && s.RefreshTokenHash == oldRefreshHash && s.RevokedAt == null)
            .ExecuteUpdateAsync(
                s => s.SetProperty(x => x.AccessTokenHash, newAccessHash)
                    .SetProperty(x => x.AccessExpiresAt, accessExpiresAt)
                    .SetProperty(x => x.RefreshTokenHash, newRefreshHash)
                    .SetProperty(x => x.RefreshExpiresAt, refreshExpiresAt),
                cancellationToken);
        return rows == 1;
    }

    public async Task RevokeSessionAsync(Guid sessionId, DateTime at, CancellationToken cancellationToken = default) =>
        await db.Sessions.Where(s => s.Id == sessionId && s.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.RevokedAt, at), cancellationToken);
}
