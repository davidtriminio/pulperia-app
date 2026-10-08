using Microsoft.EntityFrameworkCore;
using Pulperia.Api.Endpoints;
using Pulperia.Application.Accounts;
using Pulperia.Application.Management;
using Pulperia.Infrastructure.Accounts;
using Pulperia.Infrastructure.Management;
using Pulperia.Infrastructure.Persistence;

namespace Pulperia.Api;

/// <summary>
/// Arma la API. Vive aparte de <c>Program</c> para que las pruebas la levanten de verdad con su
/// propia configuración, sin paquetes de pruebas de terceros.
/// </summary>
public static class ApiHost
{
    public static WebApplication Build(string[] args, Action<WebApplicationBuilder>? configure = null)
    {
        var builder = WebApplication.CreateBuilder(args);
        builder.Services.AddOpenApi();

        // Se lee al crear cada contexto, no al registrar: así lo que fije configure también cuenta.
        builder.Services.AddDbContext<PulperiaDbContext>((sp, options) =>
            options.UseNpgsql(sp.GetRequiredService<IConfiguration>().GetConnectionString("Pulperia")));
        builder.Services.AddSingleton(TimeProvider.System);
        builder.Services.AddSingleton(sp => new PasswordHasher(
            sp.GetRequiredService<IConfiguration>().GetValue("Auth:PasswordIterations", PasswordHasher.DefaultIterations)));
        builder.Services.AddScoped<IAccountStore, EfAccountStore>();
        builder.Services.AddScoped<AccountService>();
        builder.Services.AddScoped<IManagementStore, EfManagementStore>();
        builder.Services.AddScoped<ManagementService>();

        configure?.Invoke(builder);
        RequireConnectionString(builder.Configuration);

        var app = builder.Build();
        if (app.Environment.IsDevelopment())
        {
            app.MapOpenApi();
        }

        app.MapAuthEndpoints();
        app.MapBusinessEndpoints();
        app.MapManagementEndpoints();
        return app;
    }

    /// <summary>Falla al arrancar, con el remedio, en vez de en la primera petición.</summary>
    internal static void RequireConnectionString(IConfiguration configuration)
    {
        if (string.IsNullOrWhiteSpace(configuration.GetConnectionString("Pulperia")))
        {
            throw new InvalidOperationException(
                "Falta la cadena de conexión a PostgreSQL. Defínela en la misma terminal donde ejecutas la API, por ejemplo: "
                + "$env:ConnectionStrings__Pulperia = \"Host=127.0.0.1;Port=5440;Database=pulperia;Username=pulperia;Password=dev\"");
        }
    }
}
