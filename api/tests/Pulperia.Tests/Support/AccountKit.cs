using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Accounts;
using Pulperia.Application.Management;
using Pulperia.Domain.Business;
using Pulperia.Infrastructure.Accounts;
using Pulperia.Infrastructure.Management;
using Pulperia.Infrastructure.Persistence;

namespace Pulperia.Tests.Support;

/// <summary>Un reloj que solo avanza cuando la prueba lo mueve.</summary>
public sealed class FixedClock(DateTimeOffset start) : TimeProvider
{
    private DateTimeOffset _now = start;

    public override DateTimeOffset GetUtcNow() => _now;

    public void Advance(TimeSpan by) => _now += by;
}

/// <summary>Una base real y un servicio de cuentas listo (hash rápido y reloj controlado).</summary>
public sealed class AccountKit : IAsyncDisposable
{
    public const string Password = "contrasena1";

    public static readonly DateTimeOffset Start = new(2026, 10, 9, 9, 0, 0, TimeSpan.Zero);

    private AccountKit(PulperiaDbContext db)
    {
        Db = db;
        Clock = new FixedClock(Start);
        Hasher = new PasswordHasher(iterations: 1_000);
        Service = new AccountService(new EfAccountStore(db), Hasher, Clock);
        Management = new ManagementService(new EfManagementStore(db), Clock);
    }

    public PulperiaDbContext Db { get; }

    public FixedClock Clock { get; }

    public PasswordHasher Hasher { get; }

    public AccountService Service { get; }

    public ManagementService Management { get; }

    public static async Task<AccountKit> CreateAsync(PostgresFixture postgres) =>
        new(await postgres.CreateDatabaseAsync());

    public static RegisterRequest Registration(
        string email = "ana@correo.com",
        string password = Password,
        string businessName = "Pulpería Ana",
        AmountMode amountMode = AmountMode.TwoDecimals,
        QuantityMode quantityMode = QuantityMode.Fractional) =>
        new(email, password, businessName, amountMode, quantityMode);

    /// <summary>Registra una cuenta y devuelve sus ids (falla la prueba si no se pudo).</summary>
    public async Task<RegisteredAccount> RegisterAsync(RegisterRequest? request = null)
    {
        var result = await Service.RegisterAsync(request ?? Registration());
        return result.IsSuccess ? result.Value! : throw new InvalidOperationException(string.Join(",", result.Codes));
    }

    public ValueTask DisposeAsync() => Db.DisposeAsync();
}
