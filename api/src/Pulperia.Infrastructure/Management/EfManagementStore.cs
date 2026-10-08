using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Management;
using Pulperia.Infrastructure.Persistence;

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
}
