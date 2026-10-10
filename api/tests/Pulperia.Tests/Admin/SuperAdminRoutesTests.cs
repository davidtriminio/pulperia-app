using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Pulperia.Api;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T188: las rutas de <c>/api/admin</c> solo las abre un super administrador vigente, con una
/// renovación de sesión más corta (RF-96, D-29).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SuperAdminRoutesTests(PostgresFixture postgres)
{
    private const string Probe = "/api/admin/probe";

    // La ruta de prueba cuelga del mismo grupo protegido que usan las rutas reales.
    private static void MapProbe(WebApplication app) =>
        app.MapAdminGroup().MapGet("/probe", () => Results.Json(new { ok = true }));

    private sealed record Account(string Email, Guid UserId, Guid BusinessId, string Token, string Refresh);

    private static async Task<Account> Register(ApiTestHost host, string email)
    {
        var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
        {
            email, password = "contrasena1", businessName = email, amountMode = "two_decimals", quantityMode = "fractional",
        }));
        var login = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
        return new Account(
            email, register.GetProperty("userId").GetGuid(), register.GetProperty("businessId").GetGuid(),
            login.GetProperty("accessToken").GetString()!, login.GetProperty("refreshToken").GetString()!);
    }

    private static Task MakeSuperAdmin(ApiTestHost host, Account account) =>
        host.Db.Users.Where(u => u.Id == account.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));

    // ---- el acceso

    [Fact]
    public async Task Sin_token_responde_401()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);

        var response = await host.GetAsync(Probe);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("unauthorized", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Un_token_inventado_responde_401()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);

        var response = await host.GetAsync(Probe, accessToken: "no-es-un-token");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Un_usuario_normal_responde_403_aunque_sea_dueno_de_un_negocio()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Register(host, "ana@correo.com");

        var response = await host.GetAsync(Probe, ana.Token, ana.BusinessId);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal("forbidden", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Un_super_administrador_pasa_y_no_necesita_ni_usa_un_negocio()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Register(host, "ana@correo.com");
        var beto = await Register(host, "beto@correo.com");
        await MakeSuperAdmin(host, ana);

        var without = await host.GetAsync(Probe, ana.Token);
        // Un negocio ajeno o un valor basura en la cabecera no cambia nada: no se mira.
        var foreign = await host.GetAsync(Probe, ana.Token, beto.BusinessId);

        Assert.Equal(HttpStatusCode.OK, without.StatusCode);
        Assert.Equal(HttpStatusCode.OK, foreign.StatusCode);
    }

    [Fact]
    public async Task Quitarle_la_marca_surte_efecto_en_la_siguiente_peticion_aunque_el_token_siga_vigente()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Register(host, "ana@correo.com");
        var beto = await Register(host, "beto@correo.com");
        await MakeSuperAdmin(host, ana);
        await MakeSuperAdmin(host, beto);
        Assert.Equal(HttpStatusCode.OK, (await host.GetAsync(Probe, ana.Token)).StatusCode);

        await host.Db.Users.Where(u => u.Id == ana.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, false));

        Assert.Equal(HttpStatusCode.Forbidden, (await host.GetAsync(Probe, ana.Token)).StatusCode);
    }

    [Fact]
    public async Task Un_super_administrador_suspendido_responde_403_con_su_token_vigente()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Register(host, "ana@correo.com");
        await MakeSuperAdmin(host, ana);
        await host.Db.Users.Where(u => u.Id == ana.UserId).ExecuteUpdateAsync(s => s
            .SetProperty(u => u.SuspendedAt, DateTime.UtcNow)
            .SetProperty(u => u.SuspensionReason, "Revisión"));

        var response = await host.GetAsync(Probe, ana.Token);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    // ---- las rutas reales

    [Fact]
    public async Task Toda_ruta_real_de_administracion_pasa_por_la_proteccion()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var routes = host.App.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(e => e.RoutePattern.RawText is { } raw
                && (raw.TrimEnd('/') == "/api/admin" || raw.StartsWith("/api/admin/")))
            .ToList();

        // Una ruta nueva bajo /api/admin sin la protección hace fallar esta prueba.
        Assert.All(routes, e => Assert.NotNull(e.Metadata.GetMetadata<SuperAdminOnlyMetadata>()));
    }

    [Fact]
    public async Task Fuera_de_api_admin_no_hay_rutas_de_administracion_de_plataforma()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var marked = host.App.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(e => e.Metadata.GetMetadata<SuperAdminOnlyMetadata>() is not null)
            .Where(e => !(e.RoutePattern.RawText ?? "").StartsWith("/api/admin"))
            .ToList();

        Assert.Empty(marked);
    }

    // ---- la sesión del super administrador

    private static TimeSpan RefreshLifetime(System.Text.Json.JsonElement tokens) =>
        tokens.GetProperty("refreshExpiresAt").GetDateTimeOffset() - tokens.GetProperty("accessExpiresAt").GetDateTimeOffset()
        + TimeSpan.FromMinutes(15);

    [Fact]
    public async Task La_renovacion_de_un_super_administrador_dura_12_horas_y_la_de_los_demas_90_dias()
    {
        var clock = new FixedClock(AccountKit.Start);
        await using var host = await ApiTestHost.StartAsync(postgres, clock: clock);
        var ana = await Register(host, "ana@correo.com");
        var beto = await Register(host, "beto@correo.com");
        await MakeSuperAdmin(host, ana);

        var anaLogin = await ApiTestHost.JsonOf(
            await host.PostAsync("/api/auth/login", new { email = ana.Email, password = "contrasena1" }));
        var betoLogin = await ApiTestHost.JsonOf(
            await host.PostAsync("/api/auth/login", new { email = beto.Email, password = "contrasena1" }));

        Assert.Equal(TimeSpan.FromHours(12), RefreshLifetime(anaLogin));
        Assert.Equal(TimeSpan.FromDays(90), RefreshLifetime(betoLogin));
    }

    [Fact]
    public async Task Renovar_la_sesion_de_un_super_administrador_deja_la_nueva_en_12_horas()
    {
        var clock = new FixedClock(AccountKit.Start);
        await using var host = await ApiTestHost.StartAsync(postgres, clock: clock);
        var ana = await Register(host, "ana@correo.com");
        // Su sesión nació cuando todavía no era super administrador: dura 90 días...
        await MakeSuperAdmin(host, ana);

        var refreshed = await ApiTestHost.JsonOf(
            await host.PostAsync("/api/auth/refresh", new { refreshToken = ana.Refresh }));

        // ...pero al renovarla ya cuenta como super administrador.
        Assert.Equal(TimeSpan.FromHours(12), RefreshLifetime(refreshed));
    }

    [Fact]
    public async Task Pasadas_12_horas_la_renovacion_de_un_super_administrador_ya_no_sirve()
    {
        var clock = new FixedClock(AccountKit.Start);
        await using var host = await ApiTestHost.StartAsync(postgres, clock: clock);
        var ana = await Register(host, "ana@correo.com");
        await MakeSuperAdmin(host, ana);
        var login = await ApiTestHost.JsonOf(
            await host.PostAsync("/api/auth/login", new { email = ana.Email, password = "contrasena1" }));
        var refresh = login.GetProperty("refreshToken").GetString();

        clock.Advance(TimeSpan.FromHours(12) + TimeSpan.FromMinutes(1));
        var response = await host.PostAsync("/api/auth/refresh", new { refreshToken = refresh });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("invalid_refresh_token", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }
}
