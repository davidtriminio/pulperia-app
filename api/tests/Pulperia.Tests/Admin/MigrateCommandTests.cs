using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Npgsql;
using Pulperia.Api;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T207: <c>admin migrate</c>, el comando que deja la base al día antes de arrancar la API
/// desplegada (D-33). La API no migra sola.
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class MigrateCommandTests(PostgresFixture postgres)
{
    private sealed record Run(int ExitCode, string Output, string Errors);

    private static async Task<Run> Execute(string? connectionString, params string[] args)
    {
        var stdout = new StringWriter();
        var stderr = new StringWriter();
        var exitCode = await AdminCommands.RunAsync(
            args, stdout, stderr, "sysadmin@servidor-01",
            builder =>
            {
                if (connectionString is not null)
                {
                    builder.Configuration["ConnectionStrings:Pulperia"] = connectionString;
                }
            });
        return new Run(exitCode, stdout.ToString(), stderr.ToString());
    }

    private static async Task<bool> TableExists(string connectionString, string table)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand("SELECT to_regclass(@name) IS NOT NULL", connection);
        command.Parameters.AddWithValue("name", table);
        return (bool)(await command.ExecuteScalarAsync())!;
    }

    private static async Task<int> AppliedMigrations(string connectionString)
    {
        await using var db = PostgresFixture.NewContext(connectionString);
        return (await db.Database.GetAppliedMigrationsAsync()).Count();
    }

    private static async Task<int> KnownMigrations(string connectionString)
    {
        await using var db = PostgresFixture.NewContext(connectionString);
        return db.Database.GetMigrations().Count();
    }

    [Fact]
    public async Task Sobre_una_base_vacia_crea_todo_el_esquema_y_sale_con_0()
    {
        var connectionString = await postgres.CreateEmptyDatabaseAsync();
        Assert.False(await TableExists(connectionString, "users"));

        var run = await Execute(connectionString, "migrate");

        Assert.Equal((0, ""), (run.ExitCode, run.Errors));
        Assert.True(await TableExists(connectionString, "users"));
        Assert.True(await TableExists(connectionString, "admin_audit"));
        Assert.Equal(await KnownMigrations(connectionString), await AppliedMigrations(connectionString));
        Assert.Contains("aplicó", run.Output);
    }

    [Fact]
    public async Task Sobre_una_base_al_dia_no_cambia_nada_y_sale_con_0()
    {
        var connectionString = await postgres.CreateEmptyDatabaseAsync();
        await Execute(connectionString, "migrate");
        var before = await AppliedMigrations(connectionString);

        var run = await Execute(connectionString, "migrate");

        Assert.Equal((0, ""), (run.ExitCode, run.Errors));
        Assert.Equal(before, await AppliedMigrations(connectionString));
        Assert.Contains("al día", run.Output);
    }

    [Fact]
    public async Task Aplica_solo_las_pendientes_y_conserva_los_datos()
    {
        var connectionString = await postgres.CreateEmptyDatabaseAsync();
        await using (var db = PostgresFixture.NewContext(connectionString))
        {
            // Hasta la migración anterior a la última: como una instalación vieja.
            var migrator = db.GetService<Microsoft.EntityFrameworkCore.Migrations.IMigrator>();
            var all = db.Database.GetMigrations().ToList();
            await migrator.MigrateAsync(all[^2]);
            await db.Database.ExecuteSqlAsync(
                $"INSERT INTO users (id, email, password_hash, created_at) VALUES ({Guid.CreateVersion7()}, 'ana@correo.com', 'x', now())");
        }
        Assert.True(await AppliedMigrations(connectionString) < await KnownMigrations(connectionString));

        var run = await Execute(connectionString, "migrate");

        Assert.Equal(0, run.ExitCode);
        Assert.Equal(await KnownMigrations(connectionString), await AppliedMigrations(connectionString));
        await using var check = PostgresFixture.NewContext(connectionString);
        Assert.Equal("ana@correo.com", (await check.Users.AsNoTracking().SingleAsync()).Email);
    }

    [Fact]
    public async Task Una_base_inalcanzable_sale_con_1_sin_mostrar_la_cadena_de_conexion()
    {
        const string secret = "contrasena-super-secreta-77";
        var connectionString =
            $"Host=127.0.0.1;Port=1;Database=pulperia;Username=pulperia;Password={secret};Timeout=3;Pooling=false";

        var run = await Execute(connectionString, "migrate");

        Assert.Equal(1, run.ExitCode);
        Assert.NotEmpty(run.Errors);
        Assert.DoesNotContain(secret, run.Output + run.Errors);
        Assert.DoesNotContain("Host=127.0.0.1", run.Output + run.Errors);
    }

    [Fact]
    public async Task Sin_cadena_de_conexion_sale_con_1_y_dice_que_falta()
    {
        var run = await Execute(connectionString: "", "migrate");

        Assert.Equal(1, run.ExitCode);
        Assert.Contains("cadena de conexión", run.Errors);
    }

    [Fact]
    public async Task El_uso_menciona_migrate_y_un_argumento_de_mas_se_rechaza()
    {
        var withExtra = await Execute(null, "migrate", "ana@correo.com");

        Assert.Equal(2, withExtra.ExitCode);
        Assert.Contains("migrate", withExtra.Errors);
    }
}
