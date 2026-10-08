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

    public ValueTask DisposeAsync() => Db.DisposeAsync();
}
