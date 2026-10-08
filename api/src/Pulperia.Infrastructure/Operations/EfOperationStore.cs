using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Operations;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Operations;

/// <summary>
/// El almacén de operaciones sobre EF Core y PostgreSQL. El contexto debe estar limitado a un
/// negocio con <see cref="PulperiaDbContext.WithBusiness"/>: el filtro de consultas y la
/// comprobación al guardar garantizan que nada cruza de negocio (RNF-6). El mapeo entre los
/// registros de la aplicación y las clases de persistencia es explícito (D-25).
/// </summary>
public sealed class EfOperationStore : IOperationStore
{
    private readonly PulperiaDbContext _db;
    private readonly Guid _businessId;

    public EfOperationStore(PulperiaDbContext db)
    {
        _db = db;
        _businessId = db.BusinessScope
            ?? throw new ArgumentException("El contexto debe estar limitado a un negocio.", nameof(db));
    }

    public async Task<ClientRecord?> FindClientAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Clients.AsNoTracking().SingleOrDefaultAsync(c => c.Id == id, cancellationToken);
        return entity is null ? null : ToRecord(entity);
    }

    public async Task AddClientAsync(ClientRecord client, CancellationToken cancellationToken = default)
    {
        var entity = new ClientEntity { BusinessId = _businessId };
        Copy(client, entity);
        _db.Clients.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task UpdateClientAsync(ClientRecord client, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Clients.SingleAsync(c => c.Id == client.Id, cancellationToken);
        Copy(client, entity);
        await _db.SaveChangesAsync(cancellationToken);
    }

    private static ClientRecord ToRecord(ClientEntity e) => new(
        e.Id, e.Name, e.CharacterId, e.SkinId, e.BackgroundId, e.Phone, e.Address, e.Note,
        e.Archived, e.Version, e.CreatedBy, e.CreatedAt, e.UpdatedAt);

    private static void Copy(ClientRecord r, ClientEntity e)
    {
        e.Id = r.Id;
        e.Name = r.Name;
        e.CharacterId = r.CharacterId;
        e.SkinId = r.SkinId;
        e.BackgroundId = r.BackgroundId;
        e.Phone = r.Phone;
        e.Address = r.Address;
        e.Note = r.Note;
        e.Archived = r.Archived;
        e.Version = r.Version;
        e.CreatedBy = r.CreatedBy;
        e.CreatedAt = r.CreatedAt;
        e.UpdatedAt = r.UpdatedAt;
    }
}
