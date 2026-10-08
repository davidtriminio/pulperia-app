using System.Text.Json;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T080: un dispositivo nuevo descarga todo su negocio desde el cursor cero, y nada de otros (RF-58, RNF-6).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class InitialDownloadTests(PostgresFixture postgres)
{
    private static JsonElement[] Changes(JsonElement page) => page.GetProperty("changes").EnumerateArray().ToArray();

    /// <summary>Descarga todo con el tamaño de página dado y devuelve cada cambio con el cursor final.</summary>
    private static async Task<(List<JsonElement> Changes, long Cursor)> DownloadAll(SyncKit kit, SyncAccount who, int limit)
    {
        var all = new List<JsonElement>();
        var cursor = 0L;
        bool hasMore;
        do
        {
            var page = await kit.PullOkAsync(who, cursor, limit);
            all.AddRange(Changes(page));
            cursor = page.GetProperty("cursor").GetInt64();
            hasMore = page.GetProperty("hasMore").GetBoolean();
        }
        while (hasMore);
        return (all, cursor);
    }

    private static string[] Ids(IEnumerable<JsonElement> changes, string type) => changes
        .Where(c => c.GetProperty("type").GetString() == type)
        .Select(c => c.GetProperty("entity").GetProperty("id").GetString()!)
        .Order().ToArray();

    /// <summary>Un negocio con clientes, productos, fiados y abonos; devuelve los ids creados por tipo.</summary>
    private static async Task<Dictionary<string, string[]>> Populate(SyncKit kit, SyncAccount who, Guid businessId, string tag)
    {
        var clients = Enumerable.Range(0, 6).Select(_ => Guid.CreateVersion7()).ToArray();
        var products = Enumerable.Range(0, 3).Select(_ => Guid.CreateVersion7()).ToArray();
        var fiados = clients.Select(_ => Guid.CreateVersion7()).ToArray();
        var payments = clients.Take(3).Select(_ => Guid.CreateVersion7()).ToArray();
        var operations = clients.Select((id, i) => SyncOp("client.create", id, ClientPayload($"{tag} {i}")))
            .Concat(products.Select((id, i) => SyncOp("product.create", id, new { name = $"{tag} P{i}", price = 100 + i, unit = "unit" })))
            .Concat(fiados.Select((id, i) => SyncOp("fiado.create", id, FiadoPayload(clients[i], 1000 + i))))
            .Concat(payments.Select((id, i) => SyncOp("payment.create", id, PaymentPayload(clients[i], 100))))
            .ToArray();
        var response = await kit.Host.PostAsync("/api/sync/push", new { operations }, who.Token, businessId);
        Assert.True(response.IsSuccessStatusCode, await response.Content.ReadAsStringAsync());
        string[] Sorted(Guid[] ids) => ids.Select(i => i.ToString()).Order().ToArray();
        return new()
        {
            ["client"] = Sorted(clients), ["product"] = Sorted(products), ["fiado"] = Sorted(fiados), ["payment"] = Sorted(payments),
        };
    }

    [Fact]
    public async Task Un_cursor_vacio_entrega_todo_el_negocio_en_varias_paginas()
    {
        await using var kit = await StartAsync(postgres);
        var expected = await Populate(kit, kit.Owner, kit.BusinessId, "Ana");
        var newDevice = await kit.AddEmployeeAsync("beto@correo.com");

        var (changes, cursor) = await DownloadAll(kit, newDevice, limit: 5);

        Assert.Equal(expected["client"], Ids(changes, "client"));
        Assert.Equal(expected["product"], Ids(changes, "product"));
        Assert.Equal(expected["fiado"], Ids(changes, "fiado"));
        Assert.Equal(expected["payment"], Ids(changes, "payment"));
        Assert.Equal(18, changes.Count);
        Assert.Equal(18L, cursor);
    }

    [Fact]
    public async Task No_entrega_nada_de_otros_negocios_aunque_compartan_la_base()
    {
        await using var kit = await StartAsync(postgres);
        var stranger = await RegisterAsync(kit.Host, "otra@correo.com");
        var mine = await Populate(kit, kit.Owner, kit.BusinessId, "Ana");
        var theirs = await Populate(kit, stranger, stranger.BusinessId, "Ajeno");

        var (myChanges, _) = await DownloadAll(kit, kit.Owner, limit: 7);

        var delivered = myChanges.SelectMany(c => new[] { c.GetProperty("entity").GetProperty("id").GetString()! }).ToHashSet();
        Assert.All(theirs.Values.SelectMany(v => v), id => Assert.DoesNotContain(id, delivered));
        Assert.Equal(mine.Values.Sum(v => v.Length), myChanges.Count);
        // Y un cursor ajeno tampoco abre el otro negocio: sin pertenencia, 403.
        var intruder = await kit.Host.GetAsync("/api/sync/pull?cursor=0", kit.Owner.Token, stranger.BusinessId);
        Assert.Equal(System.Net.HttpStatusCode.Forbidden, intruder.StatusCode);
    }

    [Fact]
    public async Task La_descarga_incluye_archivados_y_anulados_con_su_estado_actual()
    {
        await using var kit = await StartAsync(postgres);
        Guid client = Guid.CreateVersion7(), archived = Guid.CreateVersion7(), fiado = Guid.CreateVersion7(), payment = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", client, ClientPayload("Activa")),
            SyncOp("client.create", archived, ClientPayload("Archivada")),
            SyncOp("client.archive", archived),
            SyncOp("fiado.create", fiado, FiadoPayload(client, 900)),
            SyncOp("payment.create", payment, PaymentPayload(client, 300)),
            SyncOp("fiado.annul", fiado));

        var (changes, _) = await DownloadAll(kit, kit.Owner, limit: 200);

        JsonElement Entity(Guid id) => changes.Single(c => c.GetProperty("entity").GetProperty("id").GetGuid() == id).GetProperty("entity");
        Assert.True(Entity(archived).GetProperty("archived").GetBoolean());
        Assert.False(Entity(client).GetProperty("archived").GetBoolean());
        Assert.Equal(kit.Owner.UserId, Entity(fiado).GetProperty("annulledBy").GetGuid());
        Assert.Equal(JsonValueKind.Null, Entity(payment).GetProperty("annulledAt").ValueKind);
    }

    [Fact]
    public async Task Terminada_la_descarga_volver_a_pedir_con_el_cursor_no_trae_nada_hasta_que_haya_cambios()
    {
        await using var kit = await StartAsync(postgres);
        await Populate(kit, kit.Owner, kit.BusinessId, "Ana");
        var (_, cursor) = await DownloadAll(kit, kit.Owner, limit: 4);

        var quiet = await kit.PullOkAsync(kit.Owner, cursor);
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Nueva")));
        var news = await kit.PullOkAsync(kit.Owner, cursor);

        Assert.Empty(Changes(quiet));
        Assert.Equal(cursor, quiet.GetProperty("cursor").GetInt64());
        Assert.Equal("Nueva", Changes(news).Single().GetProperty("entity").GetProperty("name").GetString());
        Assert.Equal(cursor + 1, news.GetProperty("cursor").GetInt64());
    }

    [Fact]
    public async Task Un_negocio_sin_datos_se_descarga_vacio_y_un_cursor_futuro_tambien()
    {
        await using var kit = await StartAsync(postgres);
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ana")));

        var future = await kit.PullOkAsync(kit.Owner, cursor: 1_000);

        Assert.Empty(Changes(future));
        Assert.Equal((1_000L, false), (future.GetProperty("cursor").GetInt64(), future.GetProperty("hasMore").GetBoolean()));
    }
}
