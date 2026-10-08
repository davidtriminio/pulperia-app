using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Pulperia.Api;
using Pulperia.Domain.Admin;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Management;

/// <summary>
/// T073: <c>admin reset-password &lt;correo&gt;</c>, el comando del servidor que restablece una
/// contraseña, con auditoría y sin exponer datos de negocios (RF-81, RF-82, D-19).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ResetPasswordCommandTests(PostgresFixture postgres)
{
    private const string Operator = "sysadmin@servidor-01";

    private sealed record Run(int ExitCode, string Output, string Errors);

    private static async Task<Run> Execute(AccountKit kit, FixedClock clock, params string[] args)
    {
        var stdout = new StringWriter();
        var stderr = new StringWriter();
        var connectionString = kit.Db.Database.GetConnectionString()!;

        var exitCode = await AdminCommands.RunAsync(
            args, stdout, stderr, Operator,
            builder =>
            {
                builder.Configuration["ConnectionStrings:Pulperia"] = connectionString;
                builder.Configuration["Auth:PasswordIterations"] = "1000";
                builder.Services.AddSingleton<TimeProvider>(clock);
            });
        return new Run(exitCode, stdout.ToString(), stderr.ToString());
    }

    private static string NewPasswordFrom(Run run)
    {
        var line = run.Output.Split('\n').Single(l => l.Contains("Contraseña nueva"));
        return line[(line.LastIndexOf(": ", StringComparison.Ordinal) + 2)..].Trim();
    }

    [Fact]
    public async Task Cambia_la_contrasena_y_la_cuenta_puede_entrar_con_la_nueva_y_ya_no_con_la_vieja()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();

        var run = await Execute(kit, kit.Clock, "reset-password", "ana@correo.com");

        Assert.Equal(0, run.ExitCode);
        Assert.Equal("", run.Errors);
        var password = NewPasswordFrom(run);
        Assert.True((await kit.Service.LoginAsync("ana@correo.com", password)).IsSuccess);
        Assert.False((await kit.Service.LoginAsync("ana@correo.com", Password)).IsSuccess);
    }

    [Fact]
    public async Task La_contrasena_nueva_cumple_las_reglas_y_es_distinta_cada_vez()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();

        var first = NewPasswordFrom(await Execute(kit, kit.Clock, "reset-password", "ana@correo.com"));
        var second = NewPasswordFrom(await Execute(kit, kit.Clock, "reset-password", "ana@correo.com"));

        Assert.Equal(16, first.Length);
        Assert.Matches("^[A-Za-z0-9]{16}$", first);
        Assert.Null(Pulperia.Domain.Accounts.AccountRules.PasswordError(first));
        Assert.NotEqual(first, second);
        Assert.False((await kit.Service.LoginAsync("ana@correo.com", first)).IsSuccess);
        Assert.True((await kit.Service.LoginAsync("ana@correo.com", second)).IsSuccess);
    }

    [Fact]
    public async Task Escribe_en_admin_audit_quien_y_cuando_sin_ningun_dato_de_negocio()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();
        kit.Clock.Advance(TimeSpan.FromDays(2));

        await Execute(kit, kit.Clock, "reset-password", "ANA@correo.com");

        var audit = await kit.Db.AdminAudits.AsNoTracking().SingleAsync();
        Assert.Equal((AdminAction.ResetPassword, account.UserId, Operator, Start.UtcDateTime.AddDays(2)),
            (audit.Action, audit.TargetUserId, audit.PerformedBy, audit.PerformedAt));
    }

    [Fact]
    public async Task La_salida_no_muestra_datos_de_negocios_ni_de_otras_cuentas()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Secreta de Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Reservados"));

        var run = await Execute(kit, kit.Clock, "reset-password", "ana@correo.com");

        var everything = run.Output + run.Errors;
        Assert.Contains("ana@correo.com", everything);
        foreach (var secret in new[]
                 {
                     "Pulpería Secreta de Ana", "Abarrotes Reservados", "beto@correo.com",
                     ana.BusinessId.ToString(), beto.BusinessId.ToString(), beto.UserId.ToString(),
                 })
        {
            Assert.DoesNotContain(secret, everything);
        }
    }

    [Fact]
    public async Task Cierra_las_sesiones_abiertas_de_la_cuenta_y_deja_las_de_otras()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync(Registration("ana@correo.com"));
        await kit.RegisterAsync(Registration("beto@correo.com"));
        var anaSession = (await kit.Service.LoginAsync("ana@correo.com", Password)).Value!;
        var betoSession = (await kit.Service.LoginAsync("beto@correo.com", Password)).Value!;

        await Execute(kit, kit.Clock, "reset-password", "ana@correo.com");

        Assert.Null(await kit.Service.AuthenticateAsync(anaSession.AccessToken));
        Assert.Equal(["invalid_refresh_token"], (await kit.Service.RefreshAsync(anaSession.RefreshToken)).Codes);
        Assert.NotNull(await kit.Service.AuthenticateAsync(betoSession.AccessToken));
    }

    [Fact]
    public async Task Un_correo_sin_cuenta_falla_sin_cambiar_ni_auditar_nada()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();
        var before = (await kit.Db.Users.AsNoTracking().SingleAsync()).PasswordHash;

        var run = await Execute(kit, kit.Clock, "reset-password", "nadie@correo.com");

        Assert.Equal(1, run.ExitCode);
        Assert.Contains("No existe una cuenta", run.Errors);
        Assert.Equal("", run.Output);
        Assert.Empty(kit.Db.AdminAudits);
        Assert.Equal(before, (await kit.Db.Users.AsNoTracking().SingleAsync()).PasswordHash);
    }

    [Theory]
    [InlineData]
    [InlineData("reset-password")]
    [InlineData("reset-password", "a@b.com", "sobra")]
    [InlineData("borrar-todo", "a@b.com")]
    [InlineData("reset-password", "no-es-un-correo")]
    public async Task Un_uso_incorrecto_muestra_la_ayuda_y_no_toca_nada(params string[] args)
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();
        var before = (await kit.Db.Users.AsNoTracking().SingleAsync()).PasswordHash;

        var run = await Execute(kit, kit.Clock, args);

        Assert.Equal(2, run.ExitCode);
        Assert.Contains("Uso:", run.Errors);
        Assert.Empty(kit.Db.AdminAudits);
        Assert.Equal(before, (await kit.Db.Users.AsNoTracking().SingleAsync()).PasswordHash);
    }
}
