using Microsoft.EntityFrameworkCore;
using Pulperia.Api.Endpoints;
using Pulperia.Application.Accounts;
using Pulperia.Infrastructure.Accounts;
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

        configure?.Invoke(builder);

        var app = builder.Build();
        if (app.Environment.IsDevelopment())
        {
            app.MapOpenApi();
        }

        app.MapAuthEndpoints();
        app.MapBusinessEndpoints();
        return app;
    }
}
