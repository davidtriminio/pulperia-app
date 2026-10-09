using System.Net;
using System.Text.Json;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T084: consultas de lectura para la web, siempre dentro del negocio de la petición (RF-22, RF-41, RF-42, RF-59).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class QueryReadTests(PostgresFixture postgres)
{
    private static object Fiado(Guid client, long total, string at, params object[] items) =>
        new { clientId = client, total, occurredAt = at, items };

    private static object Payment(Guid client, long amount, string at) =>
        new { clientId = client, amount, occurredAt = at };

    private static async Task<JsonElement> GetOk(SyncKit kit, SyncAccount who, string path, Guid? business = null)
    {
        var response = await kit.Host.GetAsync(path, who.Token, business ?? kit.BusinessId);
        var body = await ApiTestHost.JsonOf(response);
        Assert.True(response.IsSuccessStatusCode, $"{(int)response.StatusCode}: {body}");
        return body;
    }

    private static string[] Names(JsonElement list) => list.EnumerateArray().Select(c => c.GetProperty("name").GetString()!).ToArray();

    private static JsonElement ByName(JsonElement list, string name) => list.EnumerateArray().Single(c => c.GetProperty("name").GetString() == name);

    // ---- Clientes con saldo (RF-22, RF-42) ----

    [Fact]
    public async Task Lista_los_clientes_activos_con_su_saldo_y_etiqueta_ordenados_por_nombre()
    {
        await using var kit = await StartAsync(postgres);
        Guid ana = Guid.CreateVersion7(), beto = Guid.CreateVersion7(), carla = Guid.CreateVersion7(), dora = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", carla, ClientPayload("carla")),
            SyncOp("client.create", ana, ClientPayload("Ana")),
            SyncOp("client.create", beto, ClientPayload("Beto")),
            SyncOp("client.create", dora, ClientPayload("Dora")),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(ana, 5000)),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(beto, 1000)),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(beto, 1500)),
            SyncOp("client.archive", dora));

        var list = await GetOk(kit, kit.Owner, "/api/clients");

        Assert.Equal(["Ana", "Beto", "carla"], Names(list));
        Assert.Equal((5000L, "debt"), (ByName(list, "Ana").GetProperty("balance").GetInt64(), ByName(list, "Ana").GetProperty("balanceLabel").GetString()));
        Assert.Equal((-500L, "credit"), (ByName(list, "Beto").GetProperty("balance").GetInt64(), ByName(list, "Beto").GetProperty("balanceLabel").GetString()));
        Assert.Equal((0L, "settled"), (ByName(list, "carla").GetProperty("balance").GetInt64(), ByName(list, "carla").GetProperty("balanceLabel").GetString()));
    }

    [Fact]
    public async Task Los_archivados_se_listan_aparte_con_su_saldo()
    {
        await using var kit = await StartAsync(postgres);
        Guid ana = Guid.CreateVersion7(), dora = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", ana, ClientPayload("Ana")),
            SyncOp("client.create", dora, ClientPayload("Dora")),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(dora, 800)),
            SyncOp("client.archive", dora));

        var archived = await GetOk(kit, kit.Owner, "/api/clients?archived=true");
        var active = await GetOk(kit, kit.Owner, "/api/clients?archived=false");

        Assert.Equal(["Dora"], Names(archived));
        Assert.Equal((800L, true), (archived[0].GetProperty("balance").GetInt64(), archived[0].GetProperty("archived").GetBoolean()));
        Assert.Equal(["Ana"], Names(active));
    }

    [Fact]
    public async Task Un_movimiento_anulado_no_cuenta_para_el_saldo()
    {
        await using var kit = await StartAsync(postgres);
        var ana = Guid.CreateVersion7();
        var annulled = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", ana, ClientPayload("Ana")),
            SyncOp("fiado.create", annulled, FiadoPayload(ana, 9000)),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(ana, 700)),
            SyncOp("fiado.annul", annulled));

        var list = await GetOk(kit, kit.Owner, "/api/clients");

        Assert.Equal(700L, list[0].GetProperty("balance").GetInt64());
    }

    [Fact]
    public async Task Un_cliente_de_la_lista_trae_sus_datos_completos()
    {
        await using var kit = await StartAsync(postgres);
        var ana = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", ana, ClientPayload("Ana", phone: "98765432", address: "Calle 1", note: "Nota")));

        var item = (await GetOk(kit, kit.Owner, "/api/clients"))[0];

        Assert.Equal(
            (ana, "char-01", "skin-1", "bg-01", "98765432", "Calle 1", "Nota", 1),
            (item.GetProperty("id").GetGuid(), item.GetProperty("characterId").GetString(), item.GetProperty("skinId").GetString(),
             item.GetProperty("backgroundId").GetString(), item.GetProperty("phone").GetString(), item.GetProperty("address").GetString(),
             item.GetProperty("note").GetString(), item.GetProperty("version").GetInt32()));
    }

    // ---- Cliente con historial (RF-41) ----

    [Fact]
    public async Task El_historial_va_en_orden_cronologico_con_anulados_marcados_e_items()
    {
        await using var kit = await StartAsync(postgres);
        var ana = Guid.CreateVersion7();
        Guid early = Guid.CreateVersion7(), late = Guid.CreateVersion7(), pay = Guid.CreateVersion7(), annulled = Guid.CreateVersion7();
        var itemId = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", ana, ClientPayload("Ana")),
            // Llegan fuera de orden: el historial se ordena por la fecha de creación en el dispositivo (D-18).
            SyncOp("fiado.create", late, Fiado(ana, 3000, "2026-10-03T10:00:00Z")),
            SyncOp("fiado.create", early, Fiado(ana, 1250, "2026-10-01T10:00:00Z", Item(quantity: 500, unitPrice: 2500, subtotal: 1250, id: itemId))),
            SyncOp("payment.create", pay, Payment(ana, 400, "2026-10-02T10:00:00Z")),
            SyncOp("fiado.create", annulled, Fiado(ana, 700, "2026-10-04T10:00:00Z")),
            SyncOp("fiado.annul", annulled));

        var detail = await GetOk(kit, kit.Owner, $"/api/clients/{ana}");

        var movements = detail.GetProperty("movements").EnumerateArray().ToArray();
        Assert.Equal([early, pay, late, annulled], movements.Select(m => m.GetProperty("id").GetGuid()).ToArray());
        Assert.Equal(["fiado", "payment", "fiado", "fiado"], movements.Select(m => m.GetProperty("kind").GetString()).ToArray());
        Assert.Equal(JsonValueKind.Null, movements[0].GetProperty("annulledAt").ValueKind);
        Assert.Equal(kit.Owner.UserId, movements[3].GetProperty("annulledBy").GetGuid());
        var item = Assert.Single(movements[0].GetProperty("items").EnumerateArray());
        Assert.Equal((itemId, 500L, 1250L), (item.GetProperty("id").GetGuid(), item.GetProperty("quantity").GetInt64(), item.GetProperty("subtotal").GetInt64()));
        Assert.False(movements[1].TryGetProperty("items", out _));
        // Saldo: 1250 + 3000 - 400 (el anulado no cuenta).
        Assert.Equal((3850L, "debt"), (detail.GetProperty("balance").GetInt64(), detail.GetProperty("balanceLabel").GetString()));
        Assert.Equal("Ana", detail.GetProperty("name").GetString());
    }

    [Fact]
    public async Task Con_la_misma_fecha_manda_el_orden_de_llegada_al_servidor()
    {
        await using var kit = await StartAsync(postgres);
        var ana = Guid.CreateVersion7();
        Guid first = Guid.CreateVersion7(), second = Guid.CreateVersion7(), third = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", ana, ClientPayload("Ana")));
        // El id más "grande" llega primero: el desempate es por llegada, no por id.
        await kit.PushOkAsync(kit.Owner, SyncOp("payment.create", first, Payment(ana, 100, "2026-10-02T10:00:00Z")));
        await kit.PushOkAsync(kit.Owner, SyncOp("fiado.create", second, Fiado(ana, 500, "2026-10-02T10:00:00Z")));
        await kit.PushOkAsync(kit.Owner, SyncOp("payment.create", third, Payment(ana, 50, "2026-10-02T10:00:00Z")));

        var detail = await GetOk(kit, kit.Owner, $"/api/clients/{ana}");

        Assert.Equal([first, second, third], detail.GetProperty("movements").EnumerateArray().Select(m => m.GetProperty("id").GetGuid()).ToArray());
        var seqs = detail.GetProperty("movements").EnumerateArray().Select(m => m.GetProperty("serverSeq").GetInt64()).ToArray();
        Assert.Equal(seqs.Order().ToArray(), seqs);
    }

    [Fact]
    public async Task Un_cliente_archivado_tambien_se_abre_y_uno_inexistente_responde_404()
    {
        await using var kit = await StartAsync(postgres);
        var dora = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", dora, ClientPayload("Dora")), SyncOp("client.archive", dora));

        var archived = await GetOk(kit, kit.Owner, $"/api/clients/{dora}");
        var missing = await kit.Host.GetAsync($"/api/clients/{Guid.CreateVersion7()}", kit.Owner.Token, kit.BusinessId);

        Assert.True(archived.GetProperty("archived").GetBoolean());
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal("client_not_found", (await ApiTestHost.JsonOf(missing)).GetProperty("code").GetString());
    }

    // ---- Productos ----

    [Fact]
    public async Task Lista_los_productos_activos_con_precio_anterior_y_los_archivados_aparte()
    {
        await using var kit = await StartAsync(postgres);
        Guid arroz = Guid.CreateVersion7(), frijol = Guid.CreateVersion7(), azucar = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("product.create", frijol, new { name = "Frijol", price = 3000, unit = "pound" }),
            SyncOp("product.create", arroz, new { name = "Arroz", price = 2500, unit = "pound" }),
            SyncOp("product.create", azucar, new { name = "Azúcar", price = 1800, unit = "kilo" }));
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("product.update", arroz, new { name = "Arroz", price = 2800, unit = "pound" }, baseVersion: 1),
            SyncOp("product.archive", azucar, baseVersion: 1));

        var active = await GetOk(kit, kit.Owner, "/api/products");
        var archived = await GetOk(kit, kit.Owner, "/api/products?archived=true");

        Assert.Equal(["Arroz", "Frijol"], Names(active));
        var arrozItem = ByName(active, "Arroz");
        Assert.Equal((2800L, 2500L, "pound"), (arrozItem.GetProperty("price").GetInt64(), arrozItem.GetProperty("previousPrice").GetInt64(), arrozItem.GetProperty("unit").GetString()));
        Assert.Equal(JsonValueKind.Null, ByName(active, "Frijol").GetProperty("previousPrice").ValueKind);
        Assert.Equal(["Azúcar"], Names(archived));
    }

    // ---- Aislamiento, permisos y parámetros ----

    [Fact]
    public async Task Ninguna_consulta_devuelve_ni_abre_datos_de_otro_negocio()
    {
        await using var kit = await StartAsync(postgres);
        var stranger = await RegisterAsync(kit.Host, "otra@correo.com");
        var mine = Guid.CreateVersion7();
        var theirs = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", mine, ClientPayload("Mía")), SyncOp("product.create", Guid.CreateVersion7(), new { name = "Mío", price = 1, unit = "unit" }));
        var response = await kit.Host.PostAsync(
            "/api/sync/push",
            new
            {
                operations = new[]
                {
                    SyncOp("client.create", theirs, ClientPayload("Ajena")),
                    SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(theirs, 999)),
                    SyncOp("product.create", Guid.CreateVersion7(), new { name = "Ajeno", price = 1, unit = "unit" }),
                },
            },
            stranger.Token, stranger.BusinessId);
        Assert.True(response.IsSuccessStatusCode);

        var clients = await GetOk(kit, kit.Owner, "/api/clients");
        var products = await GetOk(kit, kit.Owner, "/api/products");
        var foreignDetail = await kit.Host.GetAsync($"/api/clients/{theirs}", kit.Owner.Token, kit.BusinessId);
        var foreignBusiness = await kit.Host.GetAsync("/api/clients", kit.Owner.Token, stranger.BusinessId);

        Assert.Equal(["Mía"], Names(clients));
        Assert.Equal(["Mío"], Names(products));
        Assert.Equal(HttpStatusCode.NotFound, foreignDetail.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, foreignBusiness.StatusCode);
    }

    [Fact]
    public async Task Un_empleado_consulta_pero_un_removido_o_sin_sesion_no()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var carla = await kit.AddEmployeeAsync("carla@correo.com");
        await kit.RemoveAsync(carla);
        var id = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", id, ClientPayload("Ana")));

        var paths = new[] { "/api/clients", $"/api/clients/{id}", "/api/products" };
        foreach (var path in paths)
        {
            Assert.Equal(HttpStatusCode.OK, (await kit.Host.GetAsync(path, beto.Token, kit.BusinessId)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await kit.Host.GetAsync(path, carla.Token, kit.BusinessId)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await kit.Host.GetAsync(path, null, kit.BusinessId)).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await kit.Host.GetAsync(path, kit.Owner.Token)).StatusCode);
        }
    }

    [Theory]
    [InlineData("/api/clients?archived=quizas")]
    [InlineData("/api/products?archived=1")]
    public async Task Un_parametro_archived_invalido_responde_400(string path)
    {
        await using var kit = await StartAsync(postgres);

        var response = await kit.Host.GetAsync(path, kit.Owner.Token, kit.BusinessId);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    // ---- El pull entrega el orden de llegada de los movimientos (D-18) ----

    [Fact]
    public async Task El_pull_lleva_en_fiados_y_abonos_el_serverSeq_de_su_llegada_aunque_se_anulen_despues()
    {
        await using var kit = await StartAsync(postgres);
        Guid ana = Guid.CreateVersion7(), fiado = Guid.CreateVersion7(), pay = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", ana, ClientPayload("Ana")));      // seq 1
        await kit.PushOkAsync(kit.Owner, SyncOp("fiado.create", fiado, FiadoPayload(ana, 500)));    // seq 2
        await kit.PushOkAsync(kit.Owner, SyncOp("payment.create", pay, PaymentPayload(ana, 100)));  // seq 3
        await kit.PushOkAsync(kit.Owner, SyncOp("fiado.annul", fiado));                              // seq 4

        var changes = (await kit.PullOkAsync(kit.Owner)).GetProperty("changes").EnumerateArray().ToArray();

        JsonElement Entity(Guid id) => changes.Single(c => c.GetProperty("entity").GetProperty("id").GetGuid() == id).GetProperty("entity");
        Assert.Equal(2L, Entity(fiado).GetProperty("serverSeq").GetInt64());
        Assert.Equal(3L, Entity(pay).GetProperty("serverSeq").GetInt64());
        Assert.False(Entity(ana).TryGetProperty("serverSeq", out _));
    }
}
