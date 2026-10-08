using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Admin;
using Pulperia.Domain.Admin;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Admin;

/// <summary>El restablecimiento de contraseñas sobre EF Core y PostgreSQL (D-19, D-25).</summary>
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
}
