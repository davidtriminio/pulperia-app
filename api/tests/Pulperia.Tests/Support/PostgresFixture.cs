using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Infrastructure.Persistence;
using Testcontainers.PostgreSql;

namespace Pulperia.Tests.Support;

/// <summary>
/// Un PostgreSQL real y desechable (Docker) compartido por todas las pruebas de integración
/// (D-25). Cada prueba pide su propia base de datos ya migrada, así que no comparten datos.
/// </summary>
public sealed class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithImage("postgres:17-alpine")
        .Build();

    public const string Collection = "postgres";

    public async Task InitializeAsync() => await _container.StartAsync();

    public async Task DisposeAsync() => await _container.DisposeAsync();

    /// <summary>Crea una base de datos nueva, le aplica todas las migraciones y devuelve su contexto.</summary>
    public async Task<PulperiaDbContext> CreateDatabaseAsync()
    {
        var name = "test_" + Guid.NewGuid().ToString("N");
        await using (var admin = new NpgsqlConnection(_container.GetConnectionString()))
        {
            await admin.OpenAsync();
            await using var create = new NpgsqlCommand($"CREATE DATABASE {name}", admin);
            await create.ExecuteNonQueryAsync();
        }

        // Sin pool: cada prueba usa su propia base y, con pool, cada una dejaría conexiones
        // abiertas hasta agotar el límite del servidor.
        var connectionString = new NpgsqlConnectionStringBuilder(_container.GetConnectionString())
        {
            Database = name,
            Pooling = false,
        }.ConnectionString;

        var context = NewContext(connectionString);
        await context.Database.MigrateAsync();
        return context;
    }

    /// <summary>Otro contexto sobre la misma base, para comprobar lo que de verdad quedó guardado.</summary>
    public static PulperiaDbContext NewContext(string connectionString) =>
        new(new DbContextOptionsBuilder<PulperiaDbContext>().UseNpgsql(connectionString).Options);
}

[CollectionDefinition(PostgresFixture.Collection)]
public sealed class PostgresCollection : ICollectionFixture<PostgresFixture>;
