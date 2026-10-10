using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Admin;
using Pulperia.Domain.Admin;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Admin;

/// <summary>Las operaciones del administrador del servidor sobre EF Core y PostgreSQL (D-19, D-25, D-29).</summary>
public sealed class EfAdminStore(PulperiaDbContext db) : IAdminStore
{
    public async Task<Guid?> ResetPasswordAsync(
        string normalizedEmail, string newPasswordHash, string performedBy, DateTime at,
        CancellationToken cancellationToken = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        var userId = await db.Users.AsNoTracking().Where(u => u.Email == normalizedEmail)
            .Select(u => (Guid?)u.Id).SingleOrDefaultAsync(cancellationToken);
        if (userId is null)
        {
            return null;
        }

        await db.Users.Where(u => u.Id == userId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.PasswordHash, newPasswordHash), cancellationToken);
        // Quien entró con la contraseña vieja no debe seguir dentro con sus tokens.
        await db.Sessions.Where(s => s.UserId == userId && s.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.RevokedAt, at), cancellationToken);
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(), Action = AdminAction.ResetPassword, TargetUserId = userId.Value,
            PerformedBy = performedBy, PerformedAt = at,
        });
        await db.SaveChangesAsync(cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return userId;
    }

    // El mismo candado que usa el disparador de la base: dos cambios de marca no se cruzan.
    private const long SuperAdminLock = 7340186;

    public async Task<SuperAdminOutcome> SetSuperAdminAsync(
        string normalizedEmail, bool grant, string performedBy, DateTime at,
        CancellationToken cancellationToken = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock({SuperAdminLock})", cancellationToken);

        var user = await db.Users.AsNoTracking().Where(u => u.Email == normalizedEmail)
            .Select(u => new { u.Id, u.IsSuperAdmin }).SingleOrDefaultAsync(cancellationToken);
        if (user is null)
        {
            return SuperAdminOutcome.Fail("account_not_found");
        }

        var change = grant
            ? SuperAdminRules.Grant(user.IsSuperAdmin)
            : SuperAdminRules.Revoke(user.IsSuperAdmin, await db.Users.CountAsync(u => u.IsSuperAdmin, cancellationToken));
        if (!change.IsValid)
        {
            return SuperAdminOutcome.Fail(change.Error!.Value.Code());
        }

        await db.Users.Where(u => u.Id == user.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, grant), cancellationToken);
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(),
            Action = grant ? AdminAction.GrantSuperAdmin : AdminAction.RevokeSuperAdmin,
            TargetUserId = user.Id, PerformedBy = performedBy, PerformedAt = at,
        });
        await db.SaveChangesAsync(cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return SuperAdminOutcome.Done(user.Id);
    }
}
