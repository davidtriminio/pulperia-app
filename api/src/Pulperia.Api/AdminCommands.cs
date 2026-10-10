using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Pulperia.Application.Accounts;
using Pulperia.Application.Admin;
using Pulperia.Domain.Accounts;
using Pulperia.Infrastructure.Admin;
using Pulperia.Infrastructure.Persistence;

namespace Pulperia.Api;

/// <summary>
/// Comandos del administrador del servidor (D-19): se ejecutan en la máquina del servidor, no
/// son parte de la API ni tienen pantalla.
/// </summary>
public static class AdminCommands
{
    private const string Usage = """
        Uso: dotnet Pulperia.Api.dll admin reset-password <correo>
             dotnet Pulperia.Api.dll admin grant-superadmin <correo>
             dotnet Pulperia.Api.dll admin revoke-superadmin <correo>
        """;

    /// <param name="args">Lo que sigue a <c>admin</c>.</param>
    /// <param name="performedBy">Quién ejecuta el comando; queda en la auditoría.</param>
    /// <returns>0 si salió bien, 1 si falló, 2 si el uso era incorrecto.</returns>
    public static async Task<int> RunAsync(
        string[] args, TextWriter output, TextWriter errors, string performedBy,
        Action<HostApplicationBuilder>? configure = null)
    {
        if (args is not [("reset-password" or "grant-superadmin" or "revoke-superadmin") and var command, var email]
            || !AccountRules.IsValidEmail(AccountRules.NormalizeEmail(email)))
        {
            await errors.WriteLineAsync(Usage);
            return 2;
        }

        var builder = Host.CreateApplicationBuilder();
        builder.Services.AddDbContext<PulperiaDbContext>((sp, options) =>
            options.UseNpgsql(sp.GetRequiredService<IConfiguration>().GetConnectionString("Pulperia")));
        builder.Services.AddSingleton(TimeProvider.System);
        builder.Services.AddSingleton(sp => new PasswordHasher(
            sp.GetRequiredService<IConfiguration>().GetValue("Auth:PasswordIterations", PasswordHasher.DefaultIterations)));
        builder.Services.AddScoped<IAdminStore, EfAdminStore>();
        builder.Services.AddScoped<PasswordResetService>();
        builder.Services.AddScoped<SuperAdminService>();
        configure?.Invoke(builder);
        try
        {
            ApiHost.RequireConnectionString(builder.Configuration);
        }
        catch (InvalidOperationException ex)
        {
            await errors.WriteLineAsync(ex.Message);
            return 1;
        }

        using var host = builder.Build();
        await using var scope = host.Services.CreateAsyncScope();
        if (command != "reset-password")
        {
            return await SetSuperAdminAsync(
                scope.ServiceProvider.GetRequiredService<SuperAdminService>(),
                grant: command == "grant-superadmin", email, performedBy, output, errors);
        }

        var result = await scope.ServiceProvider.GetRequiredService<PasswordResetService>()
            .ResetPasswordAsync(email, performedBy);

        if (!result.IsSuccess)
        {
            await errors.WriteLineAsync("No existe una cuenta con ese correo.");
            return 1;
        }

        // Solo el correo que el administrador ya escribió y la contraseña nueva: ningún dato de negocios (RF-82).
        var normalized = AccountRules.NormalizeEmail(email);
        await output.WriteLineAsync($"Contraseña restablecida para {normalized}. Se cerraron sus sesiones abiertas.");
        await output.WriteLineAsync($"Contraseña nueva (se muestra una sola vez): {result.Value}");
        return 0;
    }

    private static async Task<int> SetSuperAdminAsync(
        SuperAdminService service, bool grant, string email, string performedBy, TextWriter output, TextWriter errors)
    {
        var result = grant
            ? await service.GrantAsync(email, performedBy)
            : await service.RevokeAsync(email, performedBy);
        var normalized = AccountRules.NormalizeEmail(email);

        if (!result.IsSuccess)
        {
            await errors.WriteLineAsync(result.Codes[0] switch
            {
                "account_not_found" => "No existe una cuenta con ese correo.",
                "already_super_admin" => $"{normalized} ya es super administrador.",
                "not_super_admin" => $"{normalized} no es super administrador.",
                "last_super_admin" => "No se puede retirar la marca al último super administrador.",
                var code => $"No se pudo completar: {code}.",
            });
            return 1;
        }

        // Solo el correo que el administrador ya escribió: ningún dato de negocios (RF-82).
        await output.WriteLineAsync(grant
            ? $"{normalized} ahora es super administrador."
            : $"{normalized} ya no es super administrador.");
        return 0;
    }
}
