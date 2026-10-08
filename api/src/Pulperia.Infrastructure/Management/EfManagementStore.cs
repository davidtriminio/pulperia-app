using Microsoft.EntityFrameworkCore;
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

    public async Task AddInvitationAsync(
        Invitation invitation, Guid createdBy, DateTime createdAt, CancellationToken cancellationToken = default)
    {
        db.Invitations.Add(InvitationEntity.FromDomain(invitation, createdBy, createdAt));
        await db.SaveChangesAsync(cancellationToken);
    }

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
            .Select(x => new InvitationOffer(x.i.Id, x.b.Id, x.b.Name, x.i.Email))
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
        var updated = await db.Memberships
            .Where(m => m.UserId == userId && m.BusinessId == businessId)
            .ExecuteUpdateAsync(
                s => s.SetProperty(m => m.Role, Role.Employee)
                    .SetProperty(m => m.Status, MembershipStatus.Active)
                    .SetProperty(m => m.RemovedAt, (DateTime?)null)
                    .SetProperty(m => m.FinalSyncUsed, false),
                cancellationToken);
        if (updated == 0)
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
}
