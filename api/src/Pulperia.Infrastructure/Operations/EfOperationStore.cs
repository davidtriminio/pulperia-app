using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Operations;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Quantities;
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

    public async Task<BusinessModes> GetModesAsync(CancellationToken cancellationToken = default)
    {
        var business = await _db.Businesses.AsNoTracking().SingleAsync(b => b.Id == _businessId, cancellationToken);
        return new BusinessModes(business.AmountMode, business.QuantityMode);
    }

    public async Task<ProductRecord?> FindProductAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Products.AsNoTracking().SingleOrDefaultAsync(p => p.Id == id, cancellationToken);
        return entity is null ? null : ToRecord(entity);
    }

    public async Task AddProductAsync(ProductRecord product, CancellationToken cancellationToken = default)
    {
        var entity = new ProductEntity { BusinessId = _businessId };
        Copy(product, entity);
        _db.Products.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task UpdateProductAsync(ProductRecord product, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Products.SingleAsync(p => p.Id == product.Id, cancellationToken);
        Copy(product, entity);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task<FiadoRecord?> FindFiadoAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var fiado = await _db.Fiados.AsNoTracking().SingleOrDefaultAsync(f => f.Id == id, cancellationToken);
        if (fiado is null)
        {
            return null;
        }
        var items = await _db.FiadoItems.AsNoTracking()
            .Where(i => i.FiadoId == id).OrderBy(i => i.Id).ToListAsync(cancellationToken);
        return new FiadoRecord(
            fiado.Id, fiado.ClientId, new Money(fiado.Total), fiado.OccurredAt, fiado.CreatedBy,
            fiado.AnnulledAt, fiado.AnnulledBy, items.Select(ToRecord).ToList());
    }

    public async Task<IReadOnlySet<Guid>> FindExistingItemIdsAsync(
        IReadOnlyCollection<Guid> itemIds, CancellationToken cancellationToken = default)
    {
        var ids = itemIds.ToArray();
        var existing = await _db.FiadoItems.AsNoTracking()
            .Where(i => ids.Contains(i.Id)).Select(i => i.Id).ToListAsync(cancellationToken);
        return existing.ToHashSet();
    }

    public async Task AddFiadoAsync(FiadoRecord fiado, CancellationToken cancellationToken = default)
    {
        _db.Fiados.Add(new FiadoEntity
        {
            Id = fiado.Id,
            BusinessId = _businessId,
            ClientId = fiado.ClientId,
            Total = fiado.Total.MinorUnits,
            OccurredAt = fiado.OccurredAt,
            CreatedBy = fiado.CreatedBy,
            AnnulledAt = fiado.AnnulledAt,
            AnnulledBy = fiado.AnnulledBy,
        });
        _db.FiadoItems.AddRange(fiado.Items.Select(i => new FiadoItemEntity
        {
            Id = i.Id,
            BusinessId = _businessId,
            FiadoId = fiado.Id,
            ProductId = i.ProductId,
            Description = i.Description,
            Quantity = i.Quantity.Milli,
            Unit = i.Unit,
            UnitPrice = i.UnitPrice.MinorUnits,
            Subtotal = i.Subtotal.MinorUnits,
        }));
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task<PaymentRecord?> FindPaymentAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var entity = await _db.Payments.AsNoTracking().SingleOrDefaultAsync(p => p.Id == id, cancellationToken);
        return entity is null ? null : ToRecord(entity);
    }

    public async Task AddPaymentAsync(PaymentRecord payment, CancellationToken cancellationToken = default)
    {
        _db.Payments.Add(new PaymentEntity
        {
            Id = payment.Id,
            BusinessId = _businessId,
            ClientId = payment.ClientId,
            Amount = payment.Amount.MinorUnits,
            OccurredAt = payment.OccurredAt,
            CreatedBy = payment.CreatedBy,
            AnnulledAt = payment.AnnulledAt,
            AnnulledBy = payment.AnnulledBy,
        });
        await _db.SaveChangesAsync(cancellationToken);
    }

    private static PaymentRecord ToRecord(PaymentEntity e) => new(
        e.Id, e.ClientId, new Money(e.Amount), e.OccurredAt, e.CreatedBy, e.AnnulledAt, e.AnnulledBy);

    private static FiadoItemRecord ToRecord(FiadoItemEntity e) => new(
        e.Id, e.ProductId, e.Description, new Quantity(e.Quantity), e.Unit, new Money(e.UnitPrice), new Money(e.Subtotal));

    private static ProductRecord ToRecord(ProductEntity e) => new(
        e.Id, e.Name, new Money(e.Price), e.Unit,
        e.PreviousPrice is { } previous ? new Money(previous) : null, e.PriceChangedAt,
        e.Archived, e.Version, e.CreatedBy, e.CreatedAt);

    private static void Copy(ProductRecord r, ProductEntity e)
    {
        e.Id = r.Id;
        e.Name = r.Name;
        e.Price = r.Price.MinorUnits;
        e.Unit = r.Unit;
        e.PreviousPrice = r.PreviousPrice?.MinorUnits;
        e.PriceChangedAt = r.PriceChangedAt;
        e.Archived = r.Archived;
        e.Version = r.Version;
        e.CreatedBy = r.CreatedBy;
        e.CreatedAt = r.CreatedAt;
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
