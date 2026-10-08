using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Pulperia.Infrastructure.Persistence;

/// <summary>
/// Solo para <c>dotnet ef</c> (generar migraciones): no se conecta a ninguna base. La
/// cadena de conexión real llega por configuración al arrancar la API.
/// </summary>
internal sealed class PulperiaDbContextFactory : IDesignTimeDbContextFactory<PulperiaDbContext>
{
    public PulperiaDbContext CreateDbContext(string[] args)
    {
        var connection = Environment.GetEnvironmentVariable("PULPERIA_DESIGN_CONNECTION")
                         ?? "Host=localhost;Database=pulperia_design;Username=postgres;Password=postgres";
        return new PulperiaDbContext(
            new DbContextOptionsBuilder<PulperiaDbContext>().UseNpgsql(connection).Options);
    }
}
