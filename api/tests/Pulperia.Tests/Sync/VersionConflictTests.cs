using Microsoft.EntityFrameworkCore;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T076: dos dispositivos editan el mismo registro; gana el servidor (RF-55, D-8).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class VersionConflictTests(PostgresFixture postgres)
{
    [Fact]
    public async Task Una_edicion_con_version_anterior_se_rechaza_y_no_sobrescribe_al_servidor()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana López")));

        // Los dos dispositivos partieron de la versión 1; el primero en llegar gana.
        var first = await kit.PushOkAsync(kit.Owner, SyncOp("client.update", client, ClientPayload("Ana María López"), baseVersion: 1));
        var stale = await kit.PushOkAsync(beto, SyncOp("client.update", client, ClientPayload("Ana L."), baseVersion: 1));

        Assert.Equal("applied", Status(first[0]));
        Assert.Equal(("rejected", "version_conflict"), (Status(stale[0]), Code(stale[0])));
        var saved = await kit.Host.Db.Clients.IgnoreQueryFilters().SingleAsync(c => c.Id == client);
        Assert.Equal(("Ana María López", 2), (saved.Name, saved.Version));
    }

    [Fact]
    public async Task Dos_ediciones_con_la_misma_base_en_un_mismo_lote_dejan_la_primera()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));

        var results = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.update", client, ClientPayload("Primera"), baseVersion: 1),
            SyncOp("client.update", client, ClientPayload("Segunda"), baseVersion: 1));

        Assert.Equal(["applied", "rejected"], results.Select(Status).ToArray());
        Assert.Equal("version_conflict", Code(results[1]));
        Assert.Equal("Primera", (await kit.Host.Db.Clients.IgnoreQueryFilters().SingleAsync(c => c.Id == client)).Name);
    }

    [Fact]
    public async Task Lo_mismo_pasa_con_el_precio_de_un_producto()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var product = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("product.create", product, new { name = "Arroz", price = 2500, unit = "pound" }));

        var owner = await kit.PushOkAsync(
            kit.Owner, SyncOp("product.update", product, new { name = "Arroz", price = 3000, unit = "pound" }, baseVersion: 1));
        var stale = await kit.PushOkAsync(
            beto, SyncOp("product.update", product, new { name = "Arroz", price = 9999, unit = "pound" }, baseVersion: 1));

        Assert.Equal("applied", Status(owner[0]));
        Assert.Equal("version_conflict", Code(stale[0]));
        var saved = await kit.Host.Db.Products.IgnoreQueryFilters().SingleAsync(p => p.Id == product);
        Assert.Equal((3000L, 2500L, 2), (saved.Price, saved.PreviousPrice, saved.Version));
    }

    [Fact]
    public async Task Un_conflicto_no_consume_seq_ni_cambia_el_registro_de_cambios()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        await kit.PushOkAsync(kit.Owner, SyncOp("client.update", client, ClientPayload("Ana M."), baseVersion: 1));
        var before = await kit.Host.Db.ChangeLog.IgnoreQueryFilters().CountAsync();

        await kit.PushOkAsync(kit.Owner, SyncOp("client.update", client, ClientPayload("Otra"), baseVersion: 1));

        Assert.Equal(before, await kit.Host.Db.ChangeLog.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Una_edicion_sin_version_base_o_de_un_registro_inexistente_se_rechaza_con_su_codigo()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));

        var results = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.update", client, ClientPayload("Sin base")),
            SyncOp("client.update", Guid.CreateVersion7(), ClientPayload("Nadie"), baseVersion: 1));

        Assert.Equal(["base_version_required", "client_not_found"], results.Select(Code).ToArray());
    }
}
