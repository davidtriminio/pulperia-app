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
}
