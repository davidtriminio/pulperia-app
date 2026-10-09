using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T083: la web envía una operación de una en una y recibe su resultado al instante (RF-59, RF-60).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SingleOperationTests(PostgresFixture postgres)
{
    private static Task<HttpResponseMessage> Send(SyncKit kit, SyncAccount who, object operation, Guid? business = null) =>
        kit.Host.PostAsync("/api/operations", operation, who.Token, business ?? kit.BusinessId);

    [Fact]
    public async Task Una_operacion_enviada_se_aplica_y_devuelve_su_resultado_en_la_misma_respuesta()
    {
        await using var kit = await SyncKit.StartAsync(postgres);
        var client = Guid.CreateVersion7();
        var op = SyncOp("client.create", client, ClientPayload("Ana"));

        var response = await Send(kit, kit.Owner, op);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal("applied", body.GetProperty("status").GetString());
        Assert.NotEqual(Guid.Empty, body.GetProperty("opId").GetGuid());
        Assert.Equal("Ana", (await kit.Host.Db.Clients.IgnoreQueryFilters().SingleAsync(c => c.Id == client)).Name);
    }

    [Fact]
    public async Task Una_operacion_rechazada_responde_con_su_codigo_y_no_guarda_nada()
    {
        await using var kit = await SyncKit.StartAsync(postgres);

        var response = await Send(kit, kit.Owner, SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(Guid.CreateVersion7(), 100)));

        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal(("rejected", "client_not_found"), (body.GetProperty("status").GetString(), body.GetProperty("code").GetString()));
        Assert.Equal(0, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Reenviar_la_misma_operacion_no_la_repite()
    {
        await using var kit = await SyncKit.StartAsync(postgres);
        var op = SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ana"));

        var first = await ApiTestHost.JsonOf(await Send(kit, kit.Owner, op));
        var again = await ApiTestHost.JsonOf(await Send(kit, kit.Owner, op));

        Assert.Equal(["applied", "duplicate"], [first.GetProperty("status").GetString(), again.GetProperty("status").GetString()]);
        Assert.Equal(1, await kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Sin_fecha_de_creacion_se_usa_la_hora_del_servidor()
    {
        var clock = new FixedClock(new DateTimeOffset(2026, 10, 11, 8, 30, 0, TimeSpan.Zero));
        await using var kit = await SyncKit.StartAsync(postgres, clock);
        var client = Guid.CreateVersion7();
        await Send(kit, kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        var fiado = Guid.CreateVersion7();

        var response = await kit.Host.PostAsync(
            "/api/operations",
            new { opId = Guid.CreateVersion7(), type = "fiado.create", entityId = fiado, payload = new { clientId = client, total = 900 } },
            kit.Owner.Token, kit.BusinessId);

        Assert.Equal("applied", (await ApiTestHost.JsonOf(response)).GetProperty("status").GetString());
        Assert.Equal(clock.GetUtcNow().UtcDateTime, (await kit.Host.Db.Fiados.IgnoreQueryFilters().SingleAsync(f => f.Id == fiado)).OccurredAt);
    }

    [Fact]
    public async Task Los_permisos_son_los_mismos_que_en_el_movil()
    {
        await using var kit = await SyncKit.StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await Send(kit, kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));

        var archive = await ApiTestHost.JsonOf(await Send(kit, beto, SyncOp("client.archive", client)));
        var payment = await ApiTestHost.JsonOf(await Send(kit, beto, SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, 50))));

        Assert.Equal(("rejected", "forbidden"), (archive.GetProperty("status").GetString(), archive.GetProperty("code").GetString()));
        Assert.Equal("applied", payment.GetProperty("status").GetString());
    }

    [Fact]
    public async Task Una_edicion_con_version_anterior_se_rechaza_igual_que_desde_el_movil()
    {
        await using var kit = await SyncKit.StartAsync(postgres);
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        await kit.PushOkAsync(kit.Owner, SyncOp("client.update", client, ClientPayload("Ana M."), baseVersion: 1));

        var stale = await ApiTestHost.JsonOf(await Send(kit, kit.Owner, SyncOp("client.update", client, ClientPayload("Otra"), baseVersion: 1)));

        Assert.Equal("version_conflict", stale.GetProperty("code").GetString());
    }

    [Fact]
    public async Task Lo_hecho_en_la_web_llega_al_movil_por_el_pull_con_las_mismas_reglas()
    {
        await using var kit = await SyncKit.StartAsync(postgres);
        var client = Guid.CreateVersion7();
        await Send(kit, kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));

        var page = await kit.PullOkAsync(kit.Owner);

        Assert.Equal("Ana", page.GetProperty("changes")[0].GetProperty("entity").GetProperty("name").GetString());
    }

    [Fact]
    public async Task Sin_sesion_401_sin_negocio_400_ajeno_403_y_un_removido_no_gasta_su_ultimo_lote()
    {
        await using var kit = await SyncKit.StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var outsider = await RegisterAsync(kit.Host, "otra@correo.com");
        var op = SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("X"));
        await kit.RemoveAsync(beto);

        var anonymous = await kit.Host.PostAsync("/api/operations", op, accessToken: null, businessId: kit.BusinessId);
        var noBusiness = await kit.Host.PostAsync("/api/operations", op, kit.Owner.Token);
        var foreign = await Send(kit, outsider, op);
        var removed = await Send(kit, beto, op);

        Assert.Equal(
            [HttpStatusCode.Unauthorized, HttpStatusCode.BadRequest, HttpStatusCode.Forbidden, HttpStatusCode.Forbidden],
            [anonymous.StatusCode, noBusiness.StatusCode, foreign.StatusCode, removed.StatusCode]);
        // La web no es el último lote del móvil: la oportunidad sigue disponible.
        var lastBatch = await kit.PushAsync(beto, SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Y")));
        Assert.Equal(HttpStatusCode.OK, lastBatch.StatusCode);
    }

    [Theory]
    [InlineData("null")]
    [InlineData("{}")]
    [InlineData("{\"opId\":\"x\",\"type\":\"client.create\",\"entityId\":\"y\"}")]
    [InlineData("no es json")]
    public async Task Un_cuerpo_mal_formado_responde_400_invalid_request(string json)
    {
        await using var kit = await SyncKit.StartAsync(postgres);

        var response = await kit.Host.SendJsonAsync(HttpMethod.Post, "/api/operations", json, kit.Owner.Token, kit.BusinessId);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }
}
