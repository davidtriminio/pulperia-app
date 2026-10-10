using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Admin;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T192: restablecer la contraseña de una cuenta desde el panel: una contraseña nueva que se ve
/// una sola vez, sesiones cerradas, auditoría y nada de datos de negocios (RF-100, RF-81, RF-82).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class PanelPasswordResetTests(PostgresFixture postgres)
{
    private sealed record World(SyncKit Kit, SyncAccount Admin, SyncAccount Ana, SyncAccount Beto);

    private async Task<World> Setup()
    {
        var kit = await StartAsync(postgres);
        var beto = await RegisterAsync(kit.Host, "beto@correo.com");
        var admin = await RegisterAsync(kit.Host, "root@plataforma.com");
        await kit.Host.Db.Users.Where(u => u.Id == admin.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));
        return new World(kit, admin, kit.Owner, beto);
    }

    private static Task<HttpResponseMessage> Reset(World w, Guid user, string? token = null) =>
        w.Kit.Host.PostAsync($"/api/admin/accounts/{user}/reset-password", new { }, token ?? w.Admin.Token);

    private static Task<HttpResponseMessage> Login(World w, string email, string password) =>
        w.Kit.Host.PostAsync("/api/auth/login", new { email, password });

    [Fact]
    public async Task Devuelve_una_contrasena_nueva_que_sirve_y_la_vieja_ya_no()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Reset(w, w.Beto.UserId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var password = (await ApiTestHost.JsonOf(response)).GetProperty("password").GetString()!;
        Assert.Matches("^[A-Za-z0-9]{16}$", password);
        Assert.Equal(HttpStatusCode.OK, (await Login(w, "beto@correo.com", password)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Login(w, "beto@correo.com", "contrasena1")).StatusCode);
    }

    [Fact]
    public async Task Cada_vez_es_distinta_y_no_queda_guardada_en_claro()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var first = (await ApiTestHost.JsonOf(await Reset(w, w.Beto.UserId))).GetProperty("password").GetString()!;
        var second = (await ApiTestHost.JsonOf(await Reset(w, w.Beto.UserId))).GetProperty("password").GetString()!;

        Assert.NotEqual(first, second);
        var hash = (await w.Kit.Host.Db.Users.AsNoTracking().SingleAsync(u => u.Id == w.Beto.UserId)).PasswordHash;
        Assert.DoesNotContain(second, hash);
    }

    [Fact]
    public async Task Cierra_las_sesiones_de_la_cuenta_y_deja_las_de_las_demas()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var login = await ApiTestHost.JsonOf(await Login(w, "beto@correo.com", "contrasena1"));
        var refresh = login.GetProperty("refreshToken").GetString();

        await Reset(w, w.Beto.UserId);

        Assert.Equal(HttpStatusCode.Unauthorized, (await w.Kit.Host.GetAsync("/api/businesses", w.Beto.Token)).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await w.Kit.Host.PostAsync("/api/auth/refresh", new { refreshToken = refresh })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await w.Kit.Host.GetAsync("/api/businesses", w.Ana.Token)).StatusCode);
    }

    [Fact]
    public async Task Queda_auditado_con_quien_lo_hizo_y_sobre_que_cuenta()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        await Reset(w, w.Beto.UserId);

        var audit = await w.Kit.Host.Db.AdminAudits.AsNoTracking().SingleAsync();
        Assert.Equal(
            (AdminAction.ResetPassword, w.Beto.UserId, null, "root@plataforma.com"),
            (audit.Action, audit.TargetUserId, audit.TargetBusinessId, audit.PerformedBy));
    }

    [Fact]
    public async Task La_respuesta_trae_solo_la_contrasena_y_ningun_dato_de_negocios()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.PushOkAsync(w.Ana,
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Cliente Secreto")));

        var response = await Reset(w, w.Ana.UserId);

        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal(["password"], body.EnumerateObject().Select(p => p.Name));
        var text = body.GetRawText();
        foreach (var secret in new[] { "Cliente Secreto", w.Ana.BusinessId.ToString(), "Negocio de ana@correo.com" })
        {
            Assert.DoesNotContain(secret, text);
        }
    }

    [Fact]
    public async Task Una_cuenta_inexistente_responde_404()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Reset(w, Guid.CreateVersion7());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("account_not_found", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        Assert.Empty(w.Kit.Host.Db.AdminAudits);
    }

    [Fact]
    public async Task Un_usuario_normal_no_puede_restablecer_contrasenas()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Reset(w, w.Beto.UserId, w.Ana.Token);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Login(w, "beto@correo.com", "contrasena1")).StatusCode);
        Assert.Equal(JsonValueKind.Object, (await ApiTestHost.JsonOf(response)).ValueKind);
    }
}
