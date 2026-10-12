using Microsoft.EntityFrameworkCore;
using Pulperia.Api.Endpoints;
using Pulperia.Application.Accounts;
using Pulperia.Application.Admin;
using Pulperia.Application.Management;
using Pulperia.Infrastructure.Accounts;
using Pulperia.Infrastructure.Admin;
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
        builder.Services.AddSingleton<RedeemRateLimiter>();
        builder.Services.AddSingleton<RegistrationRateLimiter>();
        builder.Services.AddScoped<IAdminStore, EfAdminStore>();
        builder.Services.AddScoped<PasswordResetService>();
        builder.Services.AddScoped<IPlatformStore, EfPlatformStore>();
        builder.Services.AddScoped<PlatformService>();

        configure?.Invoke(builder);
        RequireConnectionString(builder.Configuration);

        // La web de Vercel (D-33) llama a la API desde el navegador: solo los orígenes configurados.
        var origins = AllowedOrigins(builder.Configuration);
        if (origins.Length > 0)
        {
            builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy
                .WithOrigins(origins)
                .WithMethods("GET", "POST", "PATCH", "DELETE")
                .WithHeaders("Authorization", "Content-Type", BusinessAccess.BusinessHeader)
                .SetPreflightMaxAge(TimeSpan.FromHours(1))));
        }

        var app = builder.Build();
        if (origins.Length > 0)
        {
            app.UseCors();
        }
        if (app.Environment.IsDevelopment())
        {
            app.MapOpenApi();
        }

        app.MapAuthEndpoints();
        app.MapBusinessEndpoints();
        app.MapManagementEndpoints();
        app.MapAdminEndpoints();
        app.MapSyncEndpoints();
        app.MapQueryEndpoints();
        return app;
    }

    /// <summary>
    /// Los orígenes que pueden llamar a la API desde un navegador (<c>Cors:AllowedOrigins</c>, lista
    /// separada por comas). Sin espacios ni barra final; un asterisco no cuenta: no se abre a todos.
    /// </summary>
    internal static string[] AllowedOrigins(IConfiguration configuration) =>
        (configuration["Cors:AllowedOrigins"] ?? "")
            .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Select(origin => origin.TrimEnd('/'))
            .Where(origin => origin.Length > 0 && origin != "*")
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

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
