using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Pulperia.Api;
using Pulperia.Domain.Admin;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T187: <c>admin grant-superadmin</c> y <c>admin revoke-superadmin</c>, los únicos caminos para
/// marcar a un super administrador, con auditoría y sin exponer datos de negocios (RF-95, RF-101, D-29).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SuperAdminCommandTests(PostgresFixture postgres)
{
    private const string Operator = "sysadmin@servidor-01";

    private sealed record Run(int ExitCode, string Output, string Errors);

    private static async Task<Run> Execute(AccountKit kit, params string[] args)
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
                builder.Services.AddSingleton<TimeProvider>(kit.Clock);
            });
        return new Run(exitCode, stdout.ToString(), stderr.ToString());
    }

    private static async Task<bool> IsSuperAdmin(AccountKit kit, string email) =>
        (await kit.Db.Users.AsNoTracking().SingleAsync(u => u.Email == email)).IsSuperAdmin;

    [Fact]
    public async Task Marcar_a_una_cuenta_la_vuelve_super_administrador_y_queda_auditado()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync();
        kit.Clock.Advance(TimeSpan.FromHours(5));

        var run = await Execute(kit, "grant-superadmin", " ANA@correo.com ");

        Assert.Equal((0, ""), (run.ExitCode, run.Errors));
        Assert.Contains("ana@correo.com", run.Output);
        Assert.True(await IsSuperAdmin(kit, "ana@correo.com"));
        var audit = await kit.Db.AdminAudits.AsNoTracking().SingleAsync();
        Assert.Equal(
            (AdminAction.GrantSuperAdmin, ana.UserId, null, Operator, Start.UtcDateTime.AddHours(5)),
            (audit.Action, audit.TargetUserId, audit.TargetBusinessId, audit.PerformedBy, audit.PerformedAt));
    }

    [Fact]
    public async Task Marcar_a_quien_ya_lo_es_falla_y_no_audita_otra_vez()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();
        await Execute(kit, "grant-superadmin", "ana@correo.com");

        var run = await Execute(kit, "grant-superadmin", "ana@correo.com");

        Assert.Equal(1, run.ExitCode);
        Assert.Contains("ya es super administrador", run.Errors);
        Assert.Equal(1, await kit.Db.AdminAudits.CountAsync());
    }

    [Fact]
    public async Task Retirar_la_marca_funciona_si_queda_otro_y_queda_auditado()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync(Registration("ana@correo.com"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com"));
        await Execute(kit, "grant-superadmin", "ana@correo.com");
        await Execute(kit, "grant-superadmin", "beto@correo.com");

        var run = await Execute(kit, "revoke-superadmin", "beto@correo.com");

        Assert.Equal((0, ""), (run.ExitCode, run.Errors));
        Assert.False(await IsSuperAdmin(kit, "beto@correo.com"));
        Assert.True(await IsSuperAdmin(kit, "ana@correo.com"));
        var audit = await kit.Db.AdminAudits.AsNoTracking()
            .SingleAsync(a => a.Action == AdminAction.RevokeSuperAdmin);
        Assert.Equal((beto.UserId, Operator), (audit.TargetUserId, audit.PerformedBy));
    }

    [Fact]
    public async Task Retirar_la_marca_al_ultimo_se_rechaza_sin_cambiar_ni_auditar_nada()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();
        await Execute(kit, "grant-superadmin", "ana@correo.com");

        var run = await Execute(kit, "revoke-superadmin", "ana@correo.com");

        Assert.Equal(1, run.ExitCode);
        Assert.Contains("último super administrador", run.Errors);
        Assert.True(await IsSuperAdmin(kit, "ana@correo.com"));
        Assert.Equal(1, await kit.Db.AdminAudits.CountAsync());
    }

    [Fact]
    public async Task Retirar_la_marca_a_quien_no_la_tiene_falla()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync(Registration("ana@correo.com"));
        await kit.RegisterAsync(Registration("beto@correo.com"));
        await Execute(kit, "grant-superadmin", "ana@correo.com");

        var run = await Execute(kit, "revoke-superadmin", "beto@correo.com");

        Assert.Equal(1, run.ExitCode);
        Assert.Contains("no es super administrador", run.Errors);
        Assert.Equal(1, await kit.Db.AdminAudits.CountAsync());
    }

    [Theory]
    [InlineData("grant-superadmin")]
    [InlineData("revoke-superadmin")]
    public async Task Un_correo_sin_cuenta_falla_sin_auditar(string command)
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();

        var run = await Execute(kit, command, "nadie@correo.com");

        Assert.Equal(1, run.ExitCode);
        Assert.Contains("No existe una cuenta", run.Errors);
        Assert.Empty(kit.Db.AdminAudits);
    }

    [Fact]
    public async Task La_salida_no_muestra_datos_de_negocios_ni_de_otras_cuentas()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Secreta de Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Reservados"));

        var run = await Execute(kit, "grant-superadmin", "ana@correo.com");

        var everything = run.Output + run.Errors;
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
    public async Task Dos_retiros_simultaneos_no_dejan_a_la_plataforma_sin_super_administradores()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync(Registration("ana@correo.com"));
        await kit.RegisterAsync(Registration("beto@correo.com"));
        await Execute(kit, "grant-superadmin", "ana@correo.com");
        await Execute(kit, "grant-superadmin", "beto@correo.com");

        var runs = await Task.WhenAll(
            Execute(kit, "revoke-superadmin", "ana@correo.com"),
            Execute(kit, "revoke-superadmin", "beto@correo.com"));

        Assert.Equal([0, 1], runs.Select(r => r.ExitCode).Order());
        Assert.Equal(1, await kit.Db.Users.AsNoTracking().CountAsync(u => u.IsSuperAdmin));
    }

    [Theory]
    [InlineData("grant-superadmin")]
    [InlineData("revoke-superadmin")]
    public async Task Sin_correo_o_con_uno_mal_escrito_muestra_el_uso_y_sale_con_2(string command)
    {
        await using var kit = await CreateAsync(postgres);

        var missing = await Execute(kit, command);
        var invalid = await Execute(kit, command, "sin-arroba");

        foreach (var run in new[] { missing, invalid })
        {
            Assert.Equal(2, run.ExitCode);
            Assert.Contains("grant-superadmin", run.Errors);
            Assert.Contains("revoke-superadmin", run.Errors);
        }
    }
}
