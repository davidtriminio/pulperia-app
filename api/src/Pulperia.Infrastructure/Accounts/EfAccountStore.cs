using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Domain.Invitations;
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

    public async Task<InvitedAccountOutcome> TryCreateInvitedAccountAsync(
        NewInvitedAccount account, CancellationToken cancellationToken = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var invitation = await db.Invitations.AsNoTracking()
            .Where(i => i.Code == account.Code && i.Status == InvitationStatus.Pending)
            .Select(i => new { i.Id, i.BusinessId })
            .SingleOrDefaultAsync(cancellationToken);
        if (invitation is null)
        {
            return new InvitedAccountOutcome(InvitedAccountStatus.InvalidCode);
        }

        db.Users.Add(new UserEntity
        {
            Id = account.UserId, Email = account.Email, PasswordHash = account.PasswordHash, CreatedAt = account.CreatedAt,
        });
        db.Memberships.Add(new MembershipEntity
        {
            UserId = account.UserId, BusinessId = invitation.BusinessId, Role = Role.Employee, Status = MembershipStatus.Active,
        });
        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: UniqueViolation })
        {
            // El correo ya existe: el índice único es el árbitro. Nada se confirma ni se consume.
            db.ChangeTracker.Clear();
            return new InvitedAccountOutcome(InvitedAccountStatus.EmailTaken);
        }

        // Condicional: de dos registros simultáneos con el mismo código solo uno lo ve todavía pendiente.
        var accepted = await db.Invitations
            .Where(i => i.Id == invitation.Id && i.Status == InvitationStatus.Pending)
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, InvitationStatus.Accepted), cancellationToken);
        if (accepted != 1)
        {
            db.ChangeTracker.Clear();
            return new InvitedAccountOutcome(InvitedAccountStatus.InvalidCode);
        }

        await transaction.CommitAsync(cancellationToken);
        return new InvitedAccountOutcome(InvitedAccountStatus.Created, invitation.BusinessId);
    }

    public async Task<BusinessStatus?> FindBusinessStatusAsync(
        Guid businessId, CancellationToken cancellationToken = default) =>
        await db.Businesses.AsNoTracking().Where(b => b.Id == businessId)
            .Select(b => (BusinessStatus?)b.Status).SingleOrDefaultAsync(cancellationToken);

    public async Task<bool> IsActiveSuperAdminAsync(Guid userId, CancellationToken cancellationToken = default) =>
        await db.Users.AsNoTracking()
            .AnyAsync(u => u.Id == userId && u.IsSuperAdmin && u.SuspendedAt == null, cancellationToken);

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

    public async Task AddBusinessAsync(NewBusiness business, CancellationToken cancellationToken = default)
    {
        db.Businesses.Add(new BusinessEntity
        {
            Id = business.BusinessId, Name = business.Name, AmountMode = business.AmountMode,
            QuantityMode = business.QuantityMode, CreatedAt = business.CreatedAt,
        });
        db.Memberships.Add(new MembershipEntity
        {
            UserId = business.OwnerId, BusinessId = business.BusinessId, Role = Role.Owner, Status = MembershipStatus.Active,
        });
        await db.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<BusinessSummary>> ListBusinessesAsync(
        Guid userId, CancellationToken cancellationToken = default) =>
        await db.Memberships.AsNoTracking()
            .Where(m => m.UserId == userId && m.Status == MembershipStatus.Active)
            .Join(db.Businesses, m => m.BusinessId, b => b.Id,
                (m, b) => new BusinessSummary(b.Id, b.Name, m.Role, b.AmountMode, b.QuantityMode))
            .ToListAsync(cancellationToken);

    public async Task<Role?> FindActiveRoleAsync(
        Guid userId, Guid businessId, CancellationToken cancellationToken = default) =>
        await db.Memberships.AsNoTracking()
            .Where(m => m.UserId == userId && m.BusinessId == businessId && m.Status == MembershipStatus.Active)
            .Select(m => (Role?)m.Role)
            .SingleOrDefaultAsync(cancellationToken);
}
