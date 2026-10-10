using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Admin;
using Pulperia.Domain.Business;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T190: suspender y reactivar un negocio con motivo; un negocio suspendido rechaza peticiones,
/// lotes y pull sin perder datos (RF-98, RF-101, D-29).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class BusinessSuspensionTests(PostgresFixture postgres)
{
    private sealed record World(SyncKit Kit, SyncAccount Admin, SyncAccount Ana, SyncAccount Beto, SyncAccount Employee);

    private async Task<World> Setup()
    {
        var kit = await StartAsync(postgres);
        var beto = await RegisterAsync(kit.Host, "beto@correo.com");
        var employee = await kit.AddEmployeeAsync("dora@correo.com");
        var admin = await RegisterAsync(kit.Host, "root@plataforma.com");
        await kit.Host.Db.Users.Where(u => u.Id == admin.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));
        return new World(kit, admin, kit.Owner, beto, employee);
    }

    private static Task<HttpResponseMessage> Suspend(World w, Guid business, object? body, string? token = null) =>
        w.Kit.Host.PostAsync($"/api/admin/businesses/{business}/suspend", body, token ?? w.Admin.Token);

    private static Task<HttpResponseMessage> Reactivate(World w, Guid business, string? token = null) =>
        w.Kit.Host.PostAsync($"/api/admin/businesses/{business}/reactivate", new { }, token ?? w.Admin.Token);

    private static async Task<string?> CodeOf(HttpResponseMessage response) =>
        (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString();

    // ---- suspender

    [Fact]
    public async Task Suspender_con_motivo_deja_el_negocio_suspendido_y_lo_audita()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Suspend(w, w.Ana.BusinessId, new { reason = "Falta de pago" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal(("suspended", "Falta de pago"), (body.GetProperty("status").GetString(), body.GetProperty("statusReason").GetString()));
        var stored = await w.Kit.Host.Db.Businesses.AsNoTracking().SingleAsync(b => b.Id == w.Ana.BusinessId);
        Assert.Equal((BusinessStatus.Suspended, "Falta de pago"), (stored.Status, stored.StatusReason));
        var audit = await w.Kit.Host.Db.AdminAudits.AsNoTracking().SingleAsync();
        Assert.Equal(
            (AdminAction.SuspendBusiness, null, w.Ana.BusinessId, "Falta de pago", "root@plataforma.com"),
            (audit.Action, audit.TargetUserId, audit.TargetBusinessId, audit.Detail, audit.PerformedBy));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Suspender_sin_motivo_responde_400_y_no_cambia_nada(string? reason)
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Suspend(w, w.Ana.BusinessId, new { reason });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("reason_required", await CodeOf(response));
        Assert.Equal(BusinessStatus.Active, (await w.Kit.Host.Db.Businesses.AsNoTracking().SingleAsync(b => b.Id == w.Ana.BusinessId)).Status);
        Assert.Empty(w.Kit.Host.Db.AdminAudits);
    }

    [Fact]
    public async Task Suspender_uno_ya_suspendido_responde_409_sin_auditar_otra_vez()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await Suspend(w, w.Ana.BusinessId, new { reason = "Falta de pago" });

        var response = await Suspend(w, w.Ana.BusinessId, new { reason = "Otra vez" });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("business_status_invalid_transition", await CodeOf(response));
        Assert.Equal(1, await w.Kit.Host.Db.AdminAudits.CountAsync());
    }

    [Fact]
    public async Task Un_negocio_inexistente_responde_404()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Suspend(w, Guid.CreateVersion7(), new { reason = "x" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("business_not_found", await CodeOf(response));
    }

    // ---- el efecto

    [Fact]
    public async Task Un_negocio_suspendido_rechaza_peticiones_lotes_y_pull_con_su_codigo()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await Suspend(w, w.Ana.BusinessId, new { reason = "Falta de pago" });
        var biz = w.Ana.BusinessId;

        var responses = new[]
        {
            await w.Kit.Host.GetAsync("/api/clients", w.Ana.Token, biz),
            await w.Kit.Host.GetAsync("/api/products", w.Employee.Token, biz),
            await w.Kit.Host.GetAsync("/api/business", w.Ana.Token, biz),
            await w.Kit.Host.PostAsync("/api/operations", new
            {
                opId = Guid.CreateVersion7(), type = "client.create", entityId = Guid.CreateVersion7(), payload = ClientPayload("X"),
            }, w.Ana.Token, biz),
            await w.Kit.PushAsync(w.Ana, SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Y"))),
            await w.Kit.PullAsync(w.Employee),
        };

        foreach (var response in responses)
        {
            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            Assert.Equal("business_suspended", await CodeOf(response));
        }
    }

    [Fact]
    public async Task Suspender_no_toca_los_datos_ni_otros_negocios_de_las_mismas_cuentas()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        Guid client = Guid.CreateVersion7();
        await w.Kit.PushOkAsync(w.Ana, SyncOp("client.create", client, ClientPayload("Cliente Uno")));

        await Suspend(w, w.Ana.BusinessId, new { reason = "Falta de pago" });

        Assert.Equal(1, await w.Kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync(c => c.BusinessId == w.Ana.BusinessId));
        // El negocio propio de la empleada y el de Beto siguen funcionando.
        Assert.Equal(HttpStatusCode.OK, (await w.Kit.Host.GetAsync("/api/clients", w.Employee.Token, w.Employee.BusinessId)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await w.Kit.Host.GetAsync("/api/clients", w.Beto.Token, w.Beto.BusinessId)).StatusCode);
    }

    [Fact]
    public async Task Quien_no_pertenece_al_negocio_sigue_viendo_forbidden_y_no_su_estado()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await Suspend(w, w.Ana.BusinessId, new { reason = "Falta de pago" });

        var response = await w.Kit.Host.GetAsync("/api/clients", w.Beto.Token, w.Ana.BusinessId);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal("forbidden", await CodeOf(response));
    }

    // ---- reactivar

    [Fact]
    public async Task Reactivar_devuelve_el_negocio_a_la_normalidad_y_lo_que_estaba_en_cola_se_aplica()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await Suspend(w, w.Ana.BusinessId, new { reason = "Falta de pago" });
        Guid client = Guid.CreateVersion7();
        var op = SyncOp("client.create", client, ClientPayload("En cola"));
        Assert.Equal(HttpStatusCode.Forbidden, (await w.Kit.PushAsync(w.Ana, op)).StatusCode);

        var response = await Reactivate(w, w.Ana.BusinessId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal(("active", JsonValueKind.Null), (body.GetProperty("status").GetString(), body.GetProperty("statusReason").ValueKind));
        // El mismo lote que esperaba en el teléfono ahora se aplica.
        var results = await w.Kit.PushOkAsync(w.Ana, op);
        Assert.Equal("applied", Status(results[0]));
        Assert.Equal(HttpStatusCode.OK, (await w.Kit.Host.GetAsync("/api/clients", w.Employee.Token, w.Ana.BusinessId)).StatusCode);
        var reactivate = await w.Kit.Host.Db.AdminAudits.AsNoTracking().SingleAsync(a => a.Action == AdminAction.ReactivateBusiness);
        Assert.Equal((w.Ana.BusinessId, null), (reactivate.TargetBusinessId, reactivate.Detail));
    }

    [Fact]
    public async Task Reactivar_un_negocio_activo_responde_409()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Reactivate(w, w.Ana.BusinessId);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("business_status_invalid_transition", await CodeOf(response));
    }

    // ---- quién puede

    [Fact]
    public async Task Un_usuario_normal_no_puede_suspender_ni_reactivar()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var suspend = await Suspend(w, w.Ana.BusinessId, new { reason = "x" }, w.Ana.Token);
        var reactivate = await Reactivate(w, w.Ana.BusinessId, w.Ana.Token);

        Assert.Equal(HttpStatusCode.Forbidden, suspend.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, reactivate.StatusCode);
        Assert.Equal(BusinessStatus.Active, (await w.Kit.Host.Db.Businesses.AsNoTracking().SingleAsync(b => b.Id == w.Ana.BusinessId)).Status);
    }

    [Fact]
    public async Task Un_cuerpo_que_no_es_un_objeto_responde_400()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await w.Kit.Host.SendJsonAsync(
            HttpMethod.Post, $"/api/admin/businesses/{w.Ana.BusinessId}/suspend", "[1,2]", w.Admin.Token);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("invalid_request", await CodeOf(response));
    }
}
