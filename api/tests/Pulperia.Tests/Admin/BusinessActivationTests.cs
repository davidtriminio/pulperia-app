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
/// T198: el negocio del registro nace pendiente de activación, un negocio pendiente rechaza con
/// <c>business_pending</c> y el super administrador lo activa (RF-102, RF-103, RF-104, D-30).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class BusinessActivationTests(PostgresFixture postgres)
{
    private sealed class World(ApiTestHost host, SyncAccount admin, SyncAccount ana, SyncAccount beto) : IAsyncDisposable
    {
        public ApiTestHost Host { get; } = host;
        public SyncAccount Admin { get; } = admin;
        public SyncAccount Ana { get; } = ana;
        public SyncAccount Beto { get; } = beto;

        public ValueTask DisposeAsync() => Host.DisposeAsync();
    }

    /// <summary>Sin activar los negocios al registrarse: así se ve lo que pasa de verdad.</summary>
    private async Task<World> Setup()
    {
        var host = await ApiTestHost.StartAsync(postgres, activateNewBusinesses: false);
        var ana = await RegisterAsync(host, "ana@correo.com");
        var beto = await RegisterAsync(host, "beto@correo.com");
        var admin = await RegisterAsync(host, "root@plataforma.com");
        await host.Db.Users.Where(u => u.Id == admin.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));
        return new World(host, admin, ana, beto);
    }

    private static Task<HttpResponseMessage> Activate(World w, Guid business, string? token = null) =>
        w.Host.PostAsync($"/api/admin/businesses/{business}/activate", new { }, token ?? w.Admin.Token);

    private static async Task<string?> CodeOf(HttpResponseMessage response) =>
        (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString();

    private static Task<BusinessStatus> StatusOf(World w, Guid business) =>
        w.Host.Db.Businesses.AsNoTracking().Where(b => b.Id == business).Select(b => b.Status).SingleAsync();

    // ---- nacimiento (RF-102, RF-104)

    [Fact]
    public async Task El_negocio_del_registro_nace_pendiente_y_asi_lo_ve_su_dueno()
    {
        await using var w = await Setup();

        Assert.Equal(BusinessStatus.Pending, await StatusOf(w, w.Ana.BusinessId));
        var list = await ApiTestHost.JsonOf(await w.Host.GetAsync("/api/businesses", w.Ana.Token));
        Assert.Equal("pending", list[0].GetProperty("status").GetString());
    }

    [Fact]
    public async Task Un_negocio_pendiente_rechaza_peticiones_lotes_y_pull_con_business_pending()
    {
        await using var w = await Setup();
        var biz = w.Ana.BusinessId;

        var responses = new[]
        {
            await w.Host.GetAsync("/api/clients", w.Ana.Token, biz),
            await w.Host.GetAsync("/api/business", w.Ana.Token, biz),
            await w.Host.PostAsync("/api/operations", new
            {
                opId = Guid.CreateVersion7(), type = "client.create", entityId = Guid.CreateVersion7(), payload = ClientPayload("X"),
            }, w.Ana.Token, biz),
            await w.Host.PostAsync("/api/sync/push", new
            {
                operations = new[] { SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Y")) },
            }, w.Ana.Token, biz),
            await w.Host.GetAsync("/api/sync/pull?cursor=0", w.Ana.Token, biz),
        };

        foreach (var response in responses)
        {
            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            Assert.Equal("business_pending", await CodeOf(response));
        }
    }

    [Fact]
    public async Task Un_dueno_con_un_negocio_activo_crea_un_adicional_que_nace_activo()
    {
        await using var w = await Setup();
        await Activate(w, w.Ana.BusinessId);

        var response = await w.Host.PostAsync(
            "/api/businesses", new { name = "Sucursal", amountMode = "integer", quantityMode = "integer" }, w.Ana.Token);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal("active", body.GetProperty("status").GetString());
        Assert.Equal(BusinessStatus.Active, await StatusOf(w, body.GetProperty("id").GetGuid()));
    }

    [Fact]
    public async Task Quien_aun_no_tiene_un_negocio_activo_crea_uno_adicional_pendiente()
    {
        await using var w = await Setup();

        var response = await w.Host.PostAsync(
            "/api/businesses", new { name = "Otro", amountMode = "integer", quantityMode = "integer" }, w.Beto.Token);

        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal("pending", body.GetProperty("status").GetString());
    }

    [Fact]
    public async Task Un_negocio_pendiente_no_impide_usar_otro_activo_al_que_se_pertenece()
    {
        await using var w = await Setup();
        await Activate(w, w.Ana.BusinessId);
        // Beto es empleado del negocio activo de Ana; el suyo propio sigue pendiente.
        w.Host.Db.Memberships.Add(new Pulperia.Infrastructure.Persistence.Entities.MembershipEntity
        {
            UserId = w.Beto.UserId, BusinessId = w.Ana.BusinessId, Role = Pulperia.Domain.Access.Role.Employee,
        });
        await w.Host.Db.SaveChangesAsync();

        var active = await w.Host.GetAsync("/api/clients", w.Beto.Token, w.Ana.BusinessId);
        var own = await w.Host.GetAsync("/api/clients", w.Beto.Token, w.Beto.BusinessId);

        Assert.Equal(HttpStatusCode.OK, active.StatusCode);
        Assert.Equal("business_pending", await CodeOf(own));
        var list = await ApiTestHost.JsonOf(await w.Host.GetAsync("/api/businesses", w.Beto.Token));
        Assert.Equal(
            ["active", "pending"],
            list.EnumerateArray().Select(b => b.GetProperty("status").GetString()!).Order(StringComparer.Ordinal));
    }

    // ---- activar y rechazar (RF-103)

    [Fact]
    public async Task El_super_administrador_ve_los_pendientes_y_los_activa_y_desde_entonces_trabaja()
    {
        await using var w = await Setup();
        var pending = await ApiTestHost.JsonOf(await w.Host.GetAsync("/api/admin/businesses?status=pending", w.Admin.Token));
        Assert.Equal(3, pending.GetProperty("total").GetInt32());

        var response = await Activate(w, w.Ana.BusinessId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal(("active", JsonValueKind.Null), (body.GetProperty("status").GetString(), body.GetProperty("statusReason").ValueKind));
        Assert.Equal(HttpStatusCode.OK, (await w.Host.GetAsync("/api/clients", w.Ana.Token, w.Ana.BusinessId)).StatusCode);
        var results = await ApiTestHost.JsonOf(await w.Host.PostAsync("/api/sync/push", new
        {
            operations = new[] { SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ya sí")) },
        }, w.Ana.Token, w.Ana.BusinessId));
        Assert.Equal("applied", results.GetProperty("results")[0].GetProperty("status").GetString());
        var audit = await w.Host.Db.AdminAudits.AsNoTracking().SingleAsync(a => a.Action == AdminAction.ActivateBusiness);
        Assert.Equal((w.Ana.BusinessId, null, "root@plataforma.com"), (audit.TargetBusinessId, audit.Detail, audit.PerformedBy));
    }

    [Fact]
    public async Task Rechazar_un_pendiente_con_motivo_lo_deja_suspendido_y_se_puede_reactivar()
    {
        await using var w = await Setup();

        var reject = await w.Host.PostAsync(
            $"/api/admin/businesses/{w.Ana.BusinessId}/suspend", new { reason = "Datos dudosos" }, w.Admin.Token);

        Assert.Equal(HttpStatusCode.OK, reject.StatusCode);
        Assert.Equal(BusinessStatus.Suspended, await StatusOf(w, w.Ana.BusinessId));
        var blocked = await w.Host.GetAsync("/api/clients", w.Ana.Token, w.Ana.BusinessId);
        Assert.Equal("business_suspended", await CodeOf(blocked));
        var reactivate = await w.Host.PostAsync(
            $"/api/admin/businesses/{w.Ana.BusinessId}/reactivate", new { }, w.Admin.Token);
        Assert.Equal(HttpStatusCode.OK, reactivate.StatusCode);
        Assert.Equal(BusinessStatus.Active, await StatusOf(w, w.Ana.BusinessId));
    }

    [Fact]
    public async Task Activar_uno_que_ya_esta_activo_responde_409_sin_auditar_otra_vez()
    {
        await using var w = await Setup();
        await Activate(w, w.Ana.BusinessId);

        var response = await Activate(w, w.Ana.BusinessId);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("business_status_invalid_transition", await CodeOf(response));
        Assert.Equal(1, await w.Host.Db.AdminAudits.CountAsync(a => a.Action == AdminAction.ActivateBusiness));
    }

    [Fact]
    public async Task Activar_un_negocio_inexistente_responde_404()
    {
        await using var w = await Setup();

        var response = await Activate(w, Guid.CreateVersion7());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("business_not_found", await CodeOf(response));
    }

    [Fact]
    public async Task Un_usuario_normal_no_puede_activar_ni_su_propio_negocio()
    {
        await using var w = await Setup();

        var response = await Activate(w, w.Ana.BusinessId, w.Ana.Token);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(BusinessStatus.Pending, await StatusOf(w, w.Ana.BusinessId));
    }

    // ---- el registro con código no crea negocio (D-32)

    [Fact]
    public async Task Quien_se_registra_con_un_codigo_entra_a_un_negocio_activo_y_no_crea_ninguno()
    {
        await using var w = await Setup();
        await Activate(w, w.Ana.BusinessId);
        var invitation = await ApiTestHost.JsonOf(await w.Host.PostAsync(
            "/api/business/invitations", new { }, w.Ana.Token, w.Ana.BusinessId));

        var register = await w.Host.PostAsync("/api/auth/register", new
        {
            email = "dora@correo.com", password = "contrasena1", invitationCode = invitation.GetProperty("code").GetString(),
        });

        Assert.Equal(HttpStatusCode.Created, register.StatusCode);
        Assert.Equal(3, await w.Host.Db.Businesses.CountAsync());
    }
}
