using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Admin;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T193: consulta de la auditoría con paginación y filtros; de la más reciente a la más antigua y
/// de solo lectura (RF-101, D-29).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class AdminAuditQueryTests(PostgresFixture postgres)
{
    private static readonly DateTime T0 = new(2026, 10, 9, 12, 0, 0, DateTimeKind.Utc);

    private sealed record World(SyncKit Kit, SyncAccount Admin, SyncAccount Ana, SyncAccount Beto);

    /// <summary>Cuatro acciones en orden: reinicio de contraseña de Beto (comando), suspensión de Ana, de su negocio y reactivación.</summary>
    private async Task<World> Setup()
    {
        var kit = await StartAsync(postgres);
        var beto = await RegisterAsync(kit.Host, "beto@correo.com");
        var admin = await RegisterAsync(kit.Host, "root@plataforma.com");
        await kit.Host.Db.Users.Where(u => u.Id == admin.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));
        var ana = kit.Owner;

        AdminAuditEntity Row(int minutes, AdminAction action, Guid? user, Guid? business, string by, string? detail) => new()
        {
            Id = Guid.CreateVersion7(), Action = action, TargetUserId = user, TargetBusinessId = business,
            PerformedBy = by, PerformedAt = T0.AddMinutes(minutes), Detail = detail,
        };
        kit.Host.Db.AdminAudits.AddRange(
            Row(0, AdminAction.ResetPassword, beto.UserId, null, "sysadmin@servidor-01", null),
            Row(10, AdminAction.SuspendAccount, ana.UserId, null, "root@plataforma.com", "Uso indebido"),
            Row(20, AdminAction.SuspendBusiness, null, ana.BusinessId, "root@plataforma.com", "Falta de pago"),
            Row(30, AdminAction.ReactivateBusiness, null, ana.BusinessId, "root@plataforma.com", null));
        await kit.Host.Db.SaveChangesAsync();
        return new World(kit, admin, ana, beto);
    }

    private static async Task<JsonElement> GetOk(World w, string path)
    {
        var response = await w.Kit.Host.GetAsync(path, w.Admin.Token);
        var body = await ApiTestHost.JsonOf(response);
        Assert.True(response.IsSuccessStatusCode, $"{(int)response.StatusCode}: {body}");
        return body;
    }

    private static string[] Actions(JsonElement page) =>
        page.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("action").GetString()!).ToArray();

    [Fact]
    public async Task Lista_de_la_mas_reciente_a_la_mas_antigua_con_pagina_y_total()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var page = await GetOk(w, "/api/admin/audit");

        Assert.Equal(["reactivate_business", "suspend_business", "suspend_account", "reset_password"], Actions(page));
        Assert.Equal((1, 25, 4), (page.GetProperty("page").GetInt32(), page.GetProperty("pageSize").GetInt32(), page.GetProperty("total").GetInt32()));
    }

    [Fact]
    public async Task Pagina_con_el_tamano_pedido()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var second = await GetOk(w, "/api/admin/audit?page=2&pageSize=3");

        Assert.Equal(["reset_password"], Actions(second));
        Assert.Equal(4, second.GetProperty("total").GetInt32());
    }

    [Fact]
    public async Task Cada_entrada_dice_quien_cuando_que_sobre_que_y_el_motivo()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var page = await GetOk(w, "/api/admin/audit?action=suspend_account");

        var entry = page.GetProperty("items")[0];
        Assert.Equal("root@plataforma.com", entry.GetProperty("performedBy").GetString());
        Assert.Equal(T0.AddMinutes(10), entry.GetProperty("performedAt").GetDateTime().ToUniversalTime());
        Assert.Equal(w.Ana.UserId, entry.GetProperty("targetUserId").GetGuid());
        Assert.Equal("ana@correo.com", entry.GetProperty("targetEmail").GetString());
        Assert.Equal(JsonValueKind.Null, entry.GetProperty("targetBusinessId").ValueKind);
        Assert.Equal("Uso indebido", entry.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task Filtra_por_cuenta_por_negocio_y_por_accion()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var byAccount = await GetOk(w, $"/api/admin/audit?accountId={w.Beto.UserId}");
        var byBusiness = await GetOk(w, $"/api/admin/audit?businessId={w.Ana.BusinessId}");
        var byAction = await GetOk(w, "/api/admin/audit?action=reset_password");

        Assert.Equal(["reset_password"], Actions(byAccount));
        Assert.Equal(["reactivate_business", "suspend_business"], Actions(byBusiness));
        var business = byBusiness.GetProperty("items")[0];
        Assert.Equal("Negocio de ana@correo.com", business.GetProperty("targetBusinessName").GetString());
        Assert.Equal(["reset_password"], Actions(byAction));
        Assert.Equal("sysadmin@servidor-01", byAction.GetProperty("items")[0].GetProperty("performedBy").GetString());
    }

    [Fact]
    public async Task Una_accion_desconocida_o_un_id_mal_escrito_responde_400()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var action = await w.Kit.Host.GetAsync("/api/admin/audit?action=borrar_todo", w.Admin.Token);
        var id = await w.Kit.Host.GetAsync("/api/admin/audit?accountId=no-es-un-id", w.Admin.Token);

        Assert.Equal(HttpStatusCode.BadRequest, action.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, id.StatusCode);
    }

    [Fact]
    public async Task Las_entradas_traen_solo_los_campos_permitidos()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var page = await GetOk(w, "/api/admin/audit");

        string[] allowed =
        [
            "id", "action", "performedBy", "performedAt", "targetUserId", "targetEmail",
            "targetBusinessId", "targetBusinessName", "detail",
        ];
        foreach (var entry in page.GetProperty("items").EnumerateArray())
        {
            Assert.Equal(allowed.Order(), entry.EnumerateObject().Select(p => p.Name).Order());
        }
    }

    [Fact]
    public async Task Es_de_solo_lectura_y_un_usuario_normal_no_la_ve()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var normal = await w.Kit.Host.GetAsync("/api/admin/audit", w.Ana.Token, w.Ana.BusinessId);
        var delete = await w.Kit.Host.DeleteAsync("/api/admin/audit", w.Admin.Token);
        var post = await w.Kit.Host.PostAsync("/api/admin/audit", new { }, w.Admin.Token);

        Assert.Equal(HttpStatusCode.Forbidden, normal.StatusCode);
        Assert.True(delete.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.MethodNotAllowed);
        Assert.True(post.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.MethodNotAllowed);
        Assert.Equal(4, await w.Kit.Host.Db.AdminAudits.CountAsync());
    }
}
