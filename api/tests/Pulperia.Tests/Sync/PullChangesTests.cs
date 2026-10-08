using System.Net;
using System.Text.Json;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T079: los cambios posteriores a un cursor, en páginas (RF-52, RNF-7).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class PullChangesTests(PostgresFixture postgres)
{
    private static JsonElement[] Changes(JsonElement page) => page.GetProperty("changes").EnumerateArray().ToArray();

    private static string[] Names(JsonElement page) =>
        Changes(page).Select(c => c.GetProperty("entity").GetProperty("name").GetString()!).ToArray();

    /// <summary>Crea clientes "C1", "C2"... y devuelve sus ids; cada uno ocupa un seq (1, 2, ...).</summary>
    private static async Task<Guid[]> CreateClients(SyncKit kit, int count)
    {
        var ids = Enumerable.Range(1, count).Select(_ => Guid.CreateVersion7()).ToArray();
        await kit.PushOkAsync(
            kit.Owner, ids.Select((id, i) => SyncOp("client.create", id, ClientPayload($"C{i + 1}"))).ToArray());
        return ids;
    }

    [Fact]
    public async Task Devuelve_solo_lo_posterior_al_cursor_y_el_cursor_nuevo()
    {
        await using var kit = await StartAsync(postgres);
        await CreateClients(kit, 3);

        var all = await kit.PullOkAsync(kit.Owner, cursor: 0);
        var after = await kit.PullOkAsync(kit.Owner, cursor: 2);
        var none = await kit.PullOkAsync(kit.Owner, cursor: 3);

        Assert.Equal(["C1", "C2", "C3"], Names(all));
        Assert.Equal((3L, false), (all.GetProperty("cursor").GetInt64(), all.GetProperty("hasMore").GetBoolean()));
        Assert.Equal(["C3"], Names(after));
        Assert.Equal(3L, after.GetProperty("cursor").GetInt64());
        Assert.Empty(Changes(none));
        Assert.Equal((3L, false), (none.GetProperty("cursor").GetInt64(), none.GetProperty("hasMore").GetBoolean()));
    }

    [Fact]
    public async Task Sin_cambios_el_cursor_se_queda_donde_estaba()
    {
        await using var kit = await StartAsync(postgres);

        var page = await kit.PullOkAsync(kit.Owner, cursor: 0);

        Assert.Empty(Changes(page));
        Assert.Equal((0L, false), (page.GetProperty("cursor").GetInt64(), page.GetProperty("hasMore").GetBoolean()));
    }

    [Fact]
    public async Task Las_paginas_se_encadenan_con_el_cursor_sin_repetir_ni_perder_nada()
    {
        await using var kit = await StartAsync(postgres);
        await CreateClients(kit, 5);

        var names = new List<string>();
        var cursor = 0L;
        var pages = 0;
        bool hasMore;
        do
        {
            var page = await kit.PullOkAsync(kit.Owner, cursor, limit: 2);
            names.AddRange(Names(page));
            Assert.True(Changes(page).Length <= 2);
            cursor = page.GetProperty("cursor").GetInt64();
            hasMore = page.GetProperty("hasMore").GetBoolean();
            pages++;
        }
        while (hasMore);

        Assert.Equal(["C1", "C2", "C3", "C4", "C5"], names);
        Assert.Equal((3, 5L), (pages, cursor));
    }

    [Fact]
    public async Task Entrega_la_version_actual_completa_de_cada_tipo_de_registro()
    {
        await using var kit = await StartAsync(postgres);
        Guid client = Guid.CreateVersion7(), product = Guid.CreateVersion7(), fiado = Guid.CreateVersion7(), payment = Guid.CreateVersion7();
        var itemId = Guid.CreateVersion7();
        var pushed = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", client, ClientPayload("Ana López", phone: "98765432", address: "Calle 1", note: "Buena paga")),
            SyncOp("product.create", product, new { name = "Arroz", price = 2500, unit = "pound" }),
            SyncOp("fiado.create", fiado, FiadoPayload(client, 1250, Item(quantity: 500, unitPrice: 2500, subtotal: 1250, productId: product, id: itemId))),
            SyncOp("payment.create", payment, PaymentPayload(client, 400)),
            SyncOp("payment.annul", payment));
        Assert.All(pushed, r => Assert.True(Status(r) == "applied", r.ToString()));

        var changes = Changes(await kit.PullOkAsync(kit.Owner));

        JsonElement Entity(string type) => changes.Single(c => c.GetProperty("type").GetString() == type).GetProperty("entity");
        var c = Entity("client");
        Assert.Equal(
            (client, "Ana López", "char-01", "skin-1", "bg-01", "98765432", "Calle 1", "Buena paga", false, 1, kit.Owner.UserId),
            (c.GetProperty("id").GetGuid(), c.GetProperty("name").GetString(), c.GetProperty("characterId").GetString(),
             c.GetProperty("skinId").GetString(), c.GetProperty("backgroundId").GetString(), c.GetProperty("phone").GetString(),
             c.GetProperty("address").GetString(), c.GetProperty("note").GetString(), c.GetProperty("archived").GetBoolean(),
             c.GetProperty("version").GetInt32(), c.GetProperty("createdBy").GetGuid()));
        Assert.Equal(JsonValueKind.String, c.GetProperty("createdAt").ValueKind);
        Assert.Equal(JsonValueKind.String, c.GetProperty("updatedAt").ValueKind);

        var p = Entity("product");
        Assert.Equal(("Arroz", 2500L, "pound", false, 1), (p.GetProperty("name").GetString(), p.GetProperty("price").GetInt64(),
            p.GetProperty("unit").GetString(), p.GetProperty("archived").GetBoolean(), p.GetProperty("version").GetInt32()));
        Assert.Equal(JsonValueKind.Null, p.GetProperty("previousPrice").ValueKind);

        var f = Entity("fiado");
        Assert.Equal((client, 1250L, kit.Owner.UserId, JsonValueKind.Null),
            (f.GetProperty("clientId").GetGuid(), f.GetProperty("total").GetInt64(), f.GetProperty("createdBy").GetGuid(),
             f.GetProperty("annulledAt").ValueKind));
        var item = Assert.Single(f.GetProperty("items").EnumerateArray());
        Assert.Equal((itemId, product, "Arroz", 500L, "pound", 2500L, 1250L),
            (item.GetProperty("id").GetGuid(), item.GetProperty("productId").GetGuid(), item.GetProperty("description").GetString(),
             item.GetProperty("quantity").GetInt64(), item.GetProperty("unit").GetString(), item.GetProperty("unitPrice").GetInt64(),
             item.GetProperty("subtotal").GetInt64()));

        var pay = Entity("payment");
        Assert.Equal((client, 400L, kit.Owner.UserId), (pay.GetProperty("clientId").GetGuid(), pay.GetProperty("amount").GetInt64(), pay.GetProperty("createdBy").GetGuid()));
        Assert.Equal(kit.Owner.UserId, pay.GetProperty("annulledBy").GetGuid());
        Assert.Equal(JsonValueKind.String, pay.GetProperty("annulledAt").ValueKind);
    }

    [Fact]
    public async Task Un_registro_que_cambio_varias_veces_viaja_una_vez_con_su_estado_actual()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        await kit.PushOkAsync(kit.Owner, SyncOp("client.update", client, ClientPayload("Ana M."), baseVersion: 1));
        await kit.PushOkAsync(kit.Owner, SyncOp("client.update", client, ClientPayload("Ana María"), baseVersion: 2));
        await kit.PushOkAsync(kit.Owner, SyncOp("client.archive", client));

        var page = await kit.PullOkAsync(kit.Owner);

        var change = Assert.Single(Changes(page));
        Assert.Equal(("Ana María", 4, true, 4L), (
            change.GetProperty("entity").GetProperty("name").GetString(),
            change.GetProperty("entity").GetProperty("version").GetInt32(),
            change.GetProperty("entity").GetProperty("archived").GetBoolean(),
            change.GetProperty("seq").GetInt64()));
        Assert.Equal(4L, page.GetProperty("cursor").GetInt64());
    }

    [Fact]
    public async Task Los_cambios_posteriores_a_un_cursor_incluyen_lo_que_hizo_otro_dispositivo()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var ids = await CreateClients(kit, 2);
        var cursor = (await kit.PullOkAsync(beto)).GetProperty("cursor").GetInt64();

        await kit.PushOkAsync(kit.Owner, SyncOp("client.update", ids[0], ClientPayload("C1 editado"), baseVersion: 1));
        await kit.PushOkAsync(beto, SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(ids[1], 100)));
        var page = await kit.PullOkAsync(beto, cursor);

        Assert.Equal(["client", "payment"], Changes(page).Select(c => c.GetProperty("type").GetString()).ToArray());
        Assert.Equal("C1 editado", Changes(page)[0].GetProperty("entity").GetProperty("name").GetString());
    }

    [Fact]
    public async Task Un_limite_muy_grande_se_acota_y_sin_limite_se_usa_una_pagina_normal()
    {
        await using var kit = await StartAsync(postgres);
        await CreateClients(kit, 3);

        var big = await kit.PullOkAsync(kit.Owner, 0, limit: 100_000);
        var normal = await kit.PullOkAsync(kit.Owner, 0);

        Assert.Equal(3, Changes(big).Length);
        Assert.Equal(3, Changes(normal).Length);
    }

    [Fact]
    public async Task Sin_sesion_responde_401_sin_negocio_400_y_sin_pertenecer_403()
    {
        await using var kit = await StartAsync(postgres);
        var outsider = await RegisterAsync(kit.Host, "otra@correo.com");

        var anonymous = await kit.Host.GetAsync("/api/sync/pull?cursor=0", accessToken: null, businessId: kit.BusinessId);
        var noBusiness = await kit.Host.GetAsync("/api/sync/pull?cursor=0", kit.Owner.Token);
        var foreign = await kit.PullAsync(outsider);

        Assert.Equal(
            [HttpStatusCode.Unauthorized, HttpStatusCode.BadRequest, HttpStatusCode.Forbidden],
            [anonymous.StatusCode, noBusiness.StatusCode, foreign.StatusCode]);
    }

    [Theory]
    [InlineData("cursor=-1")]
    [InlineData("cursor=abc")]
    [InlineData("cursor=0&limit=0")]
    [InlineData("cursor=0&limit=-5")]
    [InlineData("cursor=0&limit=muchos")]
    public async Task Un_cursor_o_limite_invalido_responde_400_invalid_request(string query)
    {
        await using var kit = await StartAsync(postgres);

        var response = await kit.Host.GetAsync($"/api/sync/pull?{query}", kit.Owner.Token, kit.BusinessId);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Sin_cursor_se_entiende_cursor_cero()
    {
        await using var kit = await StartAsync(postgres);
        await CreateClients(kit, 2);

        var response = await kit.Host.GetAsync("/api/sync/pull", kit.Owner.Token, kit.BusinessId);

        Assert.Equal(2, Changes(await ApiTestHost.JsonOf(response)).Length);
    }
}
