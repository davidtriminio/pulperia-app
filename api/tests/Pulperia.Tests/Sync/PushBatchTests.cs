using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T074: el envío de un lote devuelve un resultado por operación (RF-52).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class PushBatchTests(PostgresFixture postgres)
{
    [Fact]
    public async Task Un_lote_devuelve_un_resultado_por_operacion_en_el_mismo_orden()
    {
        await using var kit = await StartAsync(postgres);
        var clientId = Guid.CreateVersion7();
        Guid firstOp = Guid.CreateVersion7(), secondOp = Guid.CreateVersion7();
        var first = SyncOp("client.create", clientId, ClientPayload("Ana López"), opId: firstOp);
        var second = SyncOp("product.create", Guid.CreateVersion7(), new { name = "Arroz", price = 2500, unit = "pound" }, opId: secondOp);

        var results = await kit.PushOkAsync(kit.Owner, first, second);

        Assert.Equal(2, results.Length);
        Assert.All(results, r => Assert.Equal("applied", Status(r)));
        Assert.Equal([firstOp, secondOp], results.Select(r => r.GetProperty("opId").GetGuid()).ToArray());
        Assert.Equal("Ana López", (await kit.Host.Db.Clients.IgnoreQueryFilters().SingleAsync(c => c.Id == clientId)).Name);
    }

    [Fact]
    public async Task Una_operacion_mala_se_rechaza_con_su_codigo_y_las_demas_se_aplican()
    {
        await using var kit = await StartAsync(postgres);
        var good = Guid.CreateVersion7();
        var missingClient = Guid.CreateVersion7();

        var results = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", good, ClientPayload("Ana")),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(missingClient, 500)),
            SyncOp("cosa.rara", Guid.CreateVersion7()),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(good, 500)));

        Assert.Equal(["applied", "rejected", "rejected", "applied"], results.Select(Status).ToArray());
        Assert.Equal([null, "client_not_found", "unknown_operation", null], results.Select(Code).ToArray());
        Assert.Equal(1, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Un_rechazo_lleva_su_lista_de_codigos_y_una_aplicacion_no_lleva_codigo()
    {
        await using var kit = await StartAsync(postgres);

        var results = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("cosa.rara", Guid.CreateVersion7()),
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ana")));

        Assert.Equal(["unknown_operation"], results[0].GetProperty("codes").EnumerateArray().Select(c => c.GetString()).ToArray());
        Assert.False(results[1].TryGetProperty("code", out _));
    }

    [Fact]
    public async Task Las_operaciones_de_un_lote_se_ven_entre_si_un_cliente_y_su_fiado_en_el_mismo_lote()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        var fiado = Guid.CreateVersion7();

        var results = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", client, ClientPayload("Ana")),
            SyncOp("fiado.create", fiado, FiadoPayload(client, 1500)),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, 500)));

        Assert.All(results, r => Assert.Equal("applied", Status(r)));
        Assert.Equal(1500, (await kit.Host.Db.Fiados.IgnoreQueryFilters().SingleAsync()).Total);
        Assert.Equal(1, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Un_empleado_recibe_el_rechazo_por_operacion_no_un_error_del_lote()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(beto, SyncOp("client.create", client, ClientPayload("Ana")));

        var results = await kit.PushOkAsync(
            beto,
            SyncOp("client.archive", client),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, 100)));

        Assert.Equal(["rejected", "applied"], results.Select(Status).ToArray());
        Assert.Equal("forbidden", Code(results[0]));
        Assert.False((await kit.Host.Db.Clients.IgnoreQueryFilters().SingleAsync(c => c.Id == client)).Archived);
    }

    [Fact]
    public async Task Cada_operacion_aplicada_consume_un_seq_consecutivo_del_negocio()
    {
        await using var kit = await StartAsync(postgres);

        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ana")),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(Guid.CreateVersion7(), 100)),
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Beto")));

        var seqs = await kit.Host.Db.ChangeLog.IgnoreQueryFilters().OrderBy(c => c.Seq).Select(c => c.Seq).ToListAsync();
        Assert.Equal([1L, 2L], seqs);
    }

    [Fact]
    public async Task Un_lote_vacio_se_acepta_y_no_devuelve_resultados()
    {
        await using var kit = await StartAsync(postgres);

        Assert.Empty(await kit.PushOkAsync(kit.Owner));
    }

    [Fact]
    public async Task Sin_sesion_responde_401_sin_negocio_400_y_con_un_negocio_ajeno_403()
    {
        await using var kit = await StartAsync(postgres);
        var outsider = await RegisterAsync(kit.Host, "otra@correo.com");
        var body = new { operations = Array.Empty<object>() };

        var anonymous = await kit.Host.PostAsync("/api/sync/push", body, accessToken: null, businessId: kit.BusinessId);
        var noBusiness = await kit.Host.PostAsync("/api/sync/push", body, kit.Owner.Token);
        var foreign = await kit.PushAsync(outsider);

        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, noBusiness.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, foreign.StatusCode);
    }

    [Theory]
    [InlineData("null")]
    [InlineData("{}")]
    [InlineData("{\"operations\":[{\"type\":\"client.create\"}]}")]
    [InlineData("{\"operations\":[{\"opId\":\"x\",\"type\":\"client.create\"}]}")]
    [InlineData("no es json")]
    public async Task Un_cuerpo_mal_formado_responde_400_invalid_request(string json)
    {
        await using var kit = await StartAsync(postgres);

        var response = await kit.Host.SendJsonAsync(HttpMethod.Post, "/api/sync/push", json, kit.Owner.Token, kit.BusinessId);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Un_lote_de_mas_de_500_operaciones_se_rechaza_entero_sin_aplicar_nada()
    {
        await using var kit = await StartAsync(postgres);
        var operations = Enumerable.Range(0, 501)
            .Select(i => SyncOp("client.create", Guid.CreateVersion7(), ClientPayload($"Cliente {i}")))
            .ToArray();

        var response = await kit.PushAsync(kit.Owner, operations);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("batch_too_large", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        Assert.Equal(0, await kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync());
    }
}
