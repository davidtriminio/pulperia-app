using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Admin;
using Pulperia.Domain.Business;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Domain.Access;
using Pulperia.Domain.Accounts;
using Pulperia.Domain.Admin;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Admin;

/// <summary>
/// Las consultas del panel de administración (D-29). Usa <c>IgnoreQueryFilters</c> solo para
/// <em>contar</em> filas de datos de negocio: ninguna proyección lee sus nombres ni sus montos.
/// </summary>
public sealed class EfPlatformStore(PulperiaDbContext db) : IPlatformStore
{
    public async Task<AdminPage<AdminBusiness>> ListBusinessesAsync(
        string? search, BusinessStatus? status, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = db.Businesses.AsNoTracking();
        if (status is { } wanted)
        {
            query = query.Where(b => b.Status == wanted);
        }
        if (search is not null)
        {
            var pattern = Like(search);
            query = query.Where(b => EF.Functions.ILike(b.Name, pattern)
                || db.Memberships.Any(m => m.BusinessId == b.Id && m.Role == Role.Owner && m.Status == MembershipStatus.Active
                    && db.Users.Any(u => u.Id == m.UserId && EF.Functions.ILike(u.Email, pattern))));
        }

        var total = await query.CountAsync(cancellationToken);
        var rows = await Project(query.OrderBy(b => b.Name).ThenBy(b => b.Id).Skip((page - 1) * pageSize).Take(pageSize))
            .ToListAsync(cancellationToken);
        return new AdminPage<AdminBusiness>(await WithOwnersAsync(rows, cancellationToken), page, pageSize, total);
    }

    public async Task<AdminBusiness?> FindBusinessAsync(Guid businessId, CancellationToken cancellationToken = default)
    {
        var rows = await Project(db.Businesses.AsNoTracking().Where(b => b.Id == businessId)).ToListAsync(cancellationToken);
        return (await WithOwnersAsync(rows, cancellationToken)).SingleOrDefault();
    }

    private sealed record BusinessRow(
        Guid Id, string Name, int MemberCount, DateTime CreatedAt, BusinessStatus Status, string? StatusReason,
        DateTime? LastSyncAt, int ClientCount, int ProductCount, int FiadoCount, int PaymentCount);

    private IQueryable<BusinessRow> Project(IQueryable<Persistence.Entities.BusinessEntity> businesses) =>
        businesses.Select(b => new BusinessRow(
            b.Id,
            b.Name,
            db.Memberships.Count(m => m.BusinessId == b.Id && m.Status == MembershipStatus.Active),
            b.CreatedAt,
            b.Status,
            b.StatusReason,
            db.ProcessedOps.IgnoreQueryFilters().Where(p => p.BusinessId == b.Id).Max(p => (DateTime?)p.ProcessedAt),
            db.Clients.IgnoreQueryFilters().Count(c => c.BusinessId == b.Id),
            db.Products.IgnoreQueryFilters().Count(p => p.BusinessId == b.Id),
            db.Fiados.IgnoreQueryFilters().Count(f => f.BusinessId == b.Id),
            db.Payments.IgnoreQueryFilters().Count(p => p.BusinessId == b.Id)));

    private async Task<IReadOnlyList<AdminBusiness>> WithOwnersAsync(
        List<BusinessRow> rows, CancellationToken cancellationToken)
    {
        var ids = rows.Select(r => r.Id).ToList();
        var owners = await db.Memberships.AsNoTracking()
            .Where(m => ids.Contains(m.BusinessId) && m.Role == Role.Owner && m.Status == MembershipStatus.Active)
            .Join(db.Users, m => m.UserId, u => u.Id, (m, u) => new { m.BusinessId, u.Email })
            .ToListAsync(cancellationToken);
        var byBusiness = owners.ToLookup(o => o.BusinessId, o => o.Email);

        return rows.Select(r => new AdminBusiness(
            r.Id, r.Name, byBusiness[r.Id].Order(StringComparer.Ordinal).ToList(), r.MemberCount, r.CreatedAt,
            r.Status, r.StatusReason, r.LastSyncAt, r.ClientCount, r.ProductCount, r.FiadoCount, r.PaymentCount)).ToList();
    }

    public async Task<AdminPage<AdminAccount>> ListAccountsAsync(
        string? search, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var query = db.Users.AsNoTracking();
        if (search is not null)
        {
            var pattern = Like(search);
            query = query.Where(u => EF.Functions.ILike(u.Email, pattern));
        }

        var total = await query.CountAsync(cancellationToken);
        var users = await query.OrderBy(u => u.Email).Skip((page - 1) * pageSize).Take(pageSize)
            .Select(u => new { u.Id, u.Email, u.CreatedAt, u.IsSuperAdmin, u.SuspendedAt, u.SuspensionReason })
            .ToListAsync(cancellationToken);
        return new AdminPage<AdminAccount>(
            await WithBusinessesAsync(users.Select(u => (u.Id, u.Email, u.CreatedAt, u.IsSuperAdmin, u.SuspendedAt, u.SuspensionReason)).ToList(), cancellationToken),
            page, pageSize, total);
    }

    public async Task<AdminAccount?> FindAccountAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var users = await db.Users.AsNoTracking().Where(u => u.Id == userId)
            .Select(u => new { u.Id, u.Email, u.CreatedAt, u.IsSuperAdmin, u.SuspendedAt, u.SuspensionReason })
            .ToListAsync(cancellationToken);
        return (await WithBusinessesAsync(
            users.Select(u => (u.Id, u.Email, u.CreatedAt, u.IsSuperAdmin, u.SuspendedAt, u.SuspensionReason)).ToList(),
            cancellationToken)).SingleOrDefault();
    }

    private async Task<IReadOnlyList<AdminAccount>> WithBusinessesAsync(
        List<(Guid Id, string Email, DateTime CreatedAt, bool IsSuperAdmin, DateTime? SuspendedAt, string? Reason)> users,
        CancellationToken cancellationToken)
    {
        var ids = users.Select(u => u.Id).ToList();
        var memberships = await db.Memberships.AsNoTracking()
            .Where(m => ids.Contains(m.UserId) && m.Status == MembershipStatus.Active)
            .Join(db.Businesses, m => m.BusinessId, b => b.Id,
                (m, b) => new { m.UserId, b.Id, b.Name, m.Role, b.Status })
            .ToListAsync(cancellationToken);
        var byUser = memberships.ToLookup(m => m.UserId);

        return users.Select(u => new AdminAccount(
            u.Id, u.Email, u.CreatedAt, u.IsSuperAdmin, u.SuspendedAt, u.Reason,
            byUser[u.Id].OrderBy(m => m.Name, StringComparer.Ordinal).ThenBy(m => m.Id)
                .Select(m => new AdminAccountBusiness(m.Id, m.Name, m.Role, m.Status)).ToList())).ToList();
    }

    public async Task<BusinessStatusOutcome> ChangeBusinessStatusAsync(
        Guid businessId, Func<BusinessStatus, BusinessStatusChange> change, AdminAction action,
        Guid performedByUserId, string? reason, DateTime at, CancellationToken cancellationToken = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // El negocio bloqueado: dos cambios de estado simultáneos se esperan entre sí.
        var locked = await db.Database
            .SqlQuery<int>($"SELECT 1 AS \"Value\" FROM businesses WHERE id = {businessId} FOR UPDATE")
            .ToListAsync(cancellationToken);
        if (locked.Count == 0)
        {
            return BusinessStatusOutcome.Fail("business_not_found");
        }

        var current = await db.Businesses.AsNoTracking().Where(b => b.Id == businessId)
            .Select(b => b.Status).SingleAsync(cancellationToken);
        var result = change(current);
        if (!result.IsValid)
        {
            return BusinessStatusOutcome.Fail(result.Error!.Value.Code());
        }

        var performedBy = await db.Users.AsNoTracking().Where(u => u.Id == performedByUserId)
            .Select(u => u.Email).SingleAsync(cancellationToken);
        var status = result.Status;
        var statusReason = status == BusinessStatus.Suspended ? reason : null;
        await db.Businesses.Where(b => b.Id == businessId).ExecuteUpdateAsync(
            s => s.SetProperty(b => b.Status, status).SetProperty(b => b.StatusReason, statusReason), cancellationToken);
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(), Action = action, TargetBusinessId = businessId,
            Detail = reason, PerformedBy = performedBy, PerformedAt = at,
        });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return BusinessStatusOutcome.Done((await FindBusinessAsync(businessId, cancellationToken))!);
    }

    public async Task<AccountSuspensionOutcome> ChangeAccountSuspensionAsync(
        Guid userId, bool suspend, string? reason, Guid performedByUserId, DateTime at,
        CancellationToken cancellationToken = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        var locked = await db.Database
            .SqlQuery<int>($"SELECT 1 AS \"Value\" FROM users WHERE id = {userId} FOR UPDATE")
            .ToListAsync(cancellationToken);
        if (locked.Count == 0)
        {
            return AccountSuspensionOutcome.Fail("account_not_found");
        }

        var isSuspended = await db.Users.AsNoTracking().Where(u => u.Id == userId)
            .Select(u => u.SuspendedAt != null).SingleAsync(cancellationToken);
        var change = suspend
            ? AccountSuspensionRules.Suspend(isSuspended, reason)
            : AccountSuspensionRules.Reactivate(isSuspended);
        if (!change.IsValid)
        {
            return AccountSuspensionOutcome.Fail(change.Error!.Value.Code());
        }

        var performedBy = await db.Users.AsNoTracking().Where(u => u.Id == performedByUserId)
            .Select(u => u.Email).SingleAsync(cancellationToken);
        DateTime? suspendedAt = suspend ? at : null;
        var suspensionReason = suspend ? reason : null;
        await db.Users.Where(u => u.Id == userId).ExecuteUpdateAsync(
            s => s.SetProperty(u => u.SuspendedAt, suspendedAt).SetProperty(u => u.SuspensionReason, suspensionReason),
            cancellationToken);
        if (suspend)
        {
            // Quien entró antes no debe seguir dentro con sus tokens.
            await db.Sessions.Where(s => s.UserId == userId && s.RevokedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.RevokedAt, at), cancellationToken);
        }
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(),
            Action = suspend ? AdminAction.SuspendAccount : AdminAction.ReactivateAccount,
            TargetUserId = userId, Detail = reason, PerformedBy = performedBy, PerformedAt = at,
        });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return AccountSuspensionOutcome.Done((await FindAccountAsync(userId, cancellationToken))!);
    }

    /// <summary>El texto buscado como patrón de <c>ILIKE</c>, con sus comodines escapados.</summary>
    private static string Like(string term) =>
        "%" + term.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_") + "%";
}
