using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Application.Management;
using Pulperia.Domain.Access;
using Pulperia.Domain.Invitations;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Management;

/// <summary>La gestión del negocio sobre EF Core y PostgreSQL (D-25).</summary>
public sealed class EfManagementStore(PulperiaDbContext db) : IManagementStore
{
    public async Task<BusinessSettings?> GetSettingsAsync(Guid businessId, CancellationToken cancellationToken = default) =>
        await db.Businesses.AsNoTracking().Where(b => b.Id == businessId)
            .Select(b => new BusinessSettings(b.Name, b.AmountMode, b.QuantityMode))
            .SingleOrDefaultAsync(cancellationToken);

    public async Task UpdateSettingsAsync(
        Guid businessId, BusinessSettings settings, CancellationToken cancellationToken = default) =>
        await db.Businesses.Where(b => b.Id == businessId).ExecuteUpdateAsync(
            s => s.SetProperty(b => b.Name, settings.Name)
                .SetProperty(b => b.AmountMode, settings.AmountMode)
                .SetProperty(b => b.QuantityMode, settings.QuantityMode),
            cancellationToken);

    public async Task<string?> FindUserEmailAsync(Guid userId, CancellationToken cancellationToken = default) =>
        await db.Users.AsNoTracking().Where(u => u.Id == userId).Select(u => u.Email)
            .SingleOrDefaultAsync(cancellationToken);

    public async Task<bool> IsActiveMemberByEmailAsync(
        Guid businessId, string normalizedEmail, CancellationToken cancellationToken = default) =>
        await db.Memberships.AsNoTracking().AnyAsync(
            m => m.BusinessId == businessId && m.Status == MembershipStatus.Active
                 && db.Users.Any(u => u.Id == m.UserId && u.Email == normalizedEmail),
            cancellationToken);

    public async Task<bool> HasPendingInvitationAsync(
        Guid businessId, string normalizedEmail, CancellationToken cancellationToken = default) =>
        await db.Invitations.AsNoTracking().AnyAsync(
            i => i.BusinessId == businessId && i.Email == normalizedEmail && i.Status == InvitationStatus.Pending,
            cancellationToken);

    public async Task<bool> TryAddInvitationAsync(
        Invitation invitation, Guid createdBy, DateTime createdAt, CancellationToken cancellationToken = default)
    {
        db.Invitations.Add(InvitationEntity.FromDomain(invitation, createdBy, createdAt));
        try
        {
            await db.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: "23505" })
        {
            // El índice único del código es el árbitro: el llamador genera otro.
            db.ChangeTracker.Clear();
            return false;
        }
    }

    public async Task<Invitation?> FindPendingInvitationByCodeAsync(string code, CancellationToken cancellationToken = default)
    {
        var entity = await db.Invitations.AsNoTracking()
            .SingleOrDefaultAsync(i => i.Code == code && i.Status == InvitationStatus.Pending, cancellationToken);
        return entity?.ToDomain();
    }

    public async Task<Pulperia.Domain.Business.BusinessStatus> GetStatusAsync(
        Guid businessId, CancellationToken cancellationToken = default) =>
        await db.Businesses.AsNoTracking().Where(b => b.Id == businessId)
            .Select(b => b.Status).SingleOrDefaultAsync(cancellationToken);

    public async Task<bool> IsActiveMemberAsync(Guid userId, Guid businessId, CancellationToken cancellationToken = default) =>
        await db.Memberships.AsNoTracking().AnyAsync(
            m => m.UserId == userId && m.BusinessId == businessId && m.Status == MembershipStatus.Active,
            cancellationToken);

    public async Task<Invitation?> FindInvitationAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var entity = await db.Invitations.AsNoTracking().SingleOrDefaultAsync(i => i.Id == id, cancellationToken);
        return entity?.ToDomain();
    }

    public async Task<IReadOnlyList<InvitationOffer>> ListPendingInvitationsAsync(
        string normalizedEmail, CancellationToken cancellationToken = default) =>
        await db.Invitations.AsNoTracking()
            .Where(i => i.Email == normalizedEmail && i.Status == InvitationStatus.Pending)
            .Join(db.Businesses, i => i.BusinessId, b => b.Id, (i, b) => new { i, b })
            .OrderBy(x => x.i.CreatedAt)
            .Select(x => new InvitationOffer(x.i.Id, x.b.Id, x.b.Name, x.i.Email!))
            .ToListAsync(cancellationToken);

    public async Task<bool> AcceptInvitationAsync(
        Guid invitationId, Guid userId, CancellationToken cancellationToken = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        // Condicional: solo una de dos aceptaciones simultáneas ve la invitación todavía pendiente.
        var rows = await db.Invitations
            .Where(i => i.Id == invitationId && i.Status == InvitationStatus.Pending)
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, InvitationStatus.Accepted), cancellationToken);
        if (rows != 1)
        {
            return false;
        }

        var businessId = await db.Invitations.AsNoTracking().Where(i => i.Id == invitationId)
            .Select(i => i.BusinessId).SingleAsync(cancellationToken);
        // Un removido vuelve como empleado; quien ya es miembro activo conserva su rol (no se degrada a un dueño).
        var reactivated = await db.Memberships
            .Where(m => m.UserId == userId && m.BusinessId == businessId && m.Status == MembershipStatus.Removed)
            .ExecuteUpdateAsync(
                s => s.SetProperty(m => m.Role, Role.Employee)
                    .SetProperty(m => m.Status, MembershipStatus.Active)
                    .SetProperty(m => m.RemovedAt, (DateTime?)null)
                    .SetProperty(m => m.FinalSyncUsed, false),
                cancellationToken);
        var alreadyThere = reactivated > 0
            || await db.Memberships.AnyAsync(m => m.UserId == userId && m.BusinessId == businessId, cancellationToken);
        if (!alreadyThere)
        {
            db.Memberships.Add(new MembershipEntity
            {
                UserId = userId, BusinessId = businessId, Role = Role.Employee, Status = MembershipStatus.Active,
            });
            await db.SaveChangesAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return true;
    }

    public async Task<bool> RejectInvitationAsync(Guid invitationId, CancellationToken cancellationToken = default) =>
        await db.Invitations
            .Where(i => i.Id == invitationId && i.Status == InvitationStatus.Pending)
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, InvitationStatus.Rejected), cancellationToken) == 1;

    public async Task<IReadOnlyList<Invitation>> ListPendingInvitationsOfBusinessAsync(
        Guid businessId, CancellationToken cancellationToken = default) =>
        (await db.Invitations.AsNoTracking()
            .Where(i => i.BusinessId == businessId && i.Status == InvitationStatus.Pending)
            .OrderBy(i => i.CreatedAt).ThenBy(i => i.Id)
            .ToListAsync(cancellationToken))
        .Select(i => i.ToDomain()).ToList();

    public async Task<bool> CancelInvitationAsync(Guid invitationId, CancellationToken cancellationToken = default) =>
        await db.Invitations
            .Where(i => i.Id == invitationId && i.Status == InvitationStatus.Pending)
            .ExecuteUpdateAsync(s => s.SetProperty(i => i.Status, InvitationStatus.Cancelled), cancellationToken) == 1;

    public async Task<IReadOnlyList<TeamMemberView>> ListActiveTeamAsync(
        Guid businessId, CancellationToken cancellationToken = default) =>
        await db.Memberships.AsNoTracking()
            .Where(m => m.BusinessId == businessId && m.Status == MembershipStatus.Active)
            .Join(db.Users, m => m.UserId, u => u.Id, (m, u) => new TeamMemberView(u.Id, u.Email, m.Role))
            .ToListAsync(cancellationToken);

    public async Task<TeamResult> ChangeTeamAsync(
        Guid businessId, Func<IReadOnlyList<Member>, TeamResult> change, DateTime now,
        CancellationToken cancellationToken = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // NO KEY UPDATE: los cambios de equipo se esperan entre sí, pero no frenan a quien solo
        // inserta filas que apuntan al negocio.
        await db.Database
            .SqlQuery<int>($"SELECT 1 AS \"Value\" FROM businesses WHERE id = {businessId} FOR NO KEY UPDATE")
            .ToListAsync(cancellationToken);

        var entities = await db.Memberships.Where(m => m.BusinessId == businessId).ToListAsync(cancellationToken);
        var result = change(entities.Select(e => e.ToDomain()).ToList());
        if (!result.IsValid)
        {
            return result;
        }

        foreach (var member in result.Team!)
        {
            var entity = entities.Single(e => e.UserId == member.UserId);
            if (entity.Role == member.Role && entity.Status == member.Status)
            {
                continue;
            }
            if (entity.Status == MembershipStatus.Active && member.Status == MembershipStatus.Removed)
            {
                entity.RemovedAt = now;
                entity.FinalSyncUsed = false;
            }
            entity.Role = member.Role;
            entity.Status = member.Status;
        }
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return result;
    }
}
