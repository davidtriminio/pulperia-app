using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Operations;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Infrastructure.Operations;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Tests.Support;

/// <summary>
/// Un negocio con un dueño y un empleado sobre un PostgreSQL real, y un aplicador de operaciones
/// listo para usarse. Las pruebas de T056 a T062 lo comparten.
/// </summary>
public sealed class OperationKit : IAsyncDisposable
{
    public static readonly DateTimeOffset At = new(2026, 10, 8, 12, 0, 0, TimeSpan.Zero);

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private OperationKit(PulperiaDbContext db, Guid businessId, Guid ownerId, Guid employeeId, IOperationStore store)
    {
        Db = db;
        BusinessId = businessId;
        OwnerId = ownerId;
        EmployeeId = employeeId;
        Store = store;
        Applier = new OperationApplier(store);
    }

    public PulperiaDbContext Db { get; }

    public Guid BusinessId { get; }

    public Guid OwnerId { get; }

    public Guid EmployeeId { get; }

    public IOperationStore Store { get; }

    public OperationApplier Applier { get; }

    public OperationActor Owner => new(OwnerId, Role.Owner);

    public OperationActor Employee => new(EmployeeId, Role.Employee);

    public static async Task<OperationKit> CreateAsync(
        PostgresFixture postgres,
        AmountMode amountMode = AmountMode.TwoDecimals,
        QuantityMode quantityMode = QuantityMode.Fractional,
        Func<PulperiaDbContext, IOperationStore>? storeFactory = null)
    {
        var db = await postgres.CreateDatabaseAsync();
        var owner = new UserEntity
        {
            Id = Guid.CreateVersion7(), Email = "dueno@correo.com", PasswordHash = "h", CreatedAt = At.UtcDateTime,
        };
        var employee = new UserEntity
        {
            Id = Guid.CreateVersion7(), Email = "empleado@correo.com", PasswordHash = "h", CreatedAt = At.UtcDateTime,
        };
        var business = new BusinessEntity
        {
            Id = Guid.CreateVersion7(), Name = "Pulpería Ana", AmountMode = amountMode,
            QuantityMode = quantityMode, CreatedAt = At.UtcDateTime,
        };
        db.Users.AddRange(owner, employee);
        db.Businesses.Add(business);
        await db.SaveChangesAsync();

        db.WithBusiness(business.Id);
        var store = storeFactory?.Invoke(db) ?? new EfOperationStore(db);
        return new OperationKit(db, business.Id, owner.Id, employee.Id, store);
    }

    /// <summary>Una operación con el payload dado (objeto anónimo en camelCase, como lo manda el móvil).</summary>
    public static Operation Op(
        string type,
        Guid entityId,
        object? payload = null,
        int? baseVersion = null,
        DateTimeOffset? at = null) =>
        new(Guid.CreateVersion7(), type, entityId, JsonSerializer.SerializeToElement(payload ?? new { }, Json),
            baseVersion, at ?? At);

    public static object ClientPayload(
        string name = "Ana López",
        string? phone = null,
        string? address = null,
        string? note = null) => new
        {
            name,
            characterId = "char-01",
            skinId = "skin-1",
            backgroundId = "bg-01",
            phone,
            address,
            note,
        };

    public Task<ClientEntity> GetClient(Guid id) => Db.Clients.AsNoTracking().SingleAsync(c => c.Id == id);

    public Task<ProductEntity> GetProduct(Guid id) => Db.Products.AsNoTracking().SingleAsync(p => p.Id == id);

    /// <summary>Crea un cliente por la vía normal (la operación) y devuelve su id.</summary>
    public async Task<Guid> NewClientAsync(string name = "Ana López")
    {
        var id = Guid.CreateVersion7();
        var result = await Applier.ApplyAsync(Op("client.create", id, ClientPayload(name)), Owner);
        return result.IsApplied ? id : throw new InvalidOperationException(result.Code);
    }

    /// <summary>Crea un producto por la vía normal (la operación) y devuelve su id.</summary>
    public async Task<Guid> NewProductAsync(string name = "Arroz", long price = 2500, string unit = "pound")
    {
        var id = Guid.CreateVersion7();
        var result = await Applier.ApplyAsync(Op("product.create", id, new { name, price, unit }), Owner);
        return result.IsApplied ? id : throw new InvalidOperationException(result.Code);
    }

    /// <summary>Un ítem de fiado tal como lo encola el móvil.</summary>
    public static object Item(
        long quantity = 1000, long unitPrice = 2500, long? subtotal = null, Guid? productId = null,
        string description = "Arroz", string unit = "pound", Guid? id = null) => new
        {
            id = id ?? Guid.CreateVersion7(),
            productId,
            description,
            quantity,
            unit,
            unitPrice,
            subtotal = subtotal ?? (quantity * unitPrice + 500) / 1000,
        };

    public static object FiadoPayload(Guid clientId, long total, params object[] items) => new
    {
        clientId,
        total,
        occurredAt = At.UtcDateTime.ToString("O"),
        items,
    };

    public Task<FiadoEntity> GetFiado(Guid id) => Db.Fiados.AsNoTracking().SingleAsync(f => f.Id == id);

    public Task<List<FiadoItemEntity>> GetItems(Guid fiadoId) =>
        Db.FiadoItems.AsNoTracking().Where(i => i.FiadoId == fiadoId).OrderBy(i => i.Id).ToListAsync();

    public ValueTask DisposeAsync() => Db.DisposeAsync();
}
