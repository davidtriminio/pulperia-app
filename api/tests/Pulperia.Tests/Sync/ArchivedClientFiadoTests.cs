using Microsoft.EntityFrameworkCore;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T082: un fiado registrado sin conexión a un cliente que otro dispositivo archivó (RF-85).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ArchivedClientFiadoTests(PostgresFixture postgres)
{
    [Fact]
    public async Task El_fiado_se_acepta_y_el_cliente_sigue_archivado_con_el_saldo_actualizado()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")), SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, 1000)));

        // La dueña archiva al cliente; Beto, sin conexión, todavía lo ve activo y le fía.
        await kit.PushOkAsync(kit.Owner, SyncOp("client.archive", client));
        var fiado = Guid.CreateVersion7();
        var results = await kit.PushOkAsync(beto, SyncOp("fiado.create", fiado, FiadoPayload(client, 2500)));

        Assert.Equal("applied", Status(results[0]));
        var saved = await kit.Host.Db.Clients.IgnoreQueryFilters().AsNoTracking().SingleAsync(c => c.Id == client);
        Assert.True(saved.Archived);
        Assert.Equal(beto.UserId, (await kit.Host.Db.Fiados.IgnoreQueryFilters().AsNoTracking().SingleAsync(f => f.Id == fiado)).CreatedBy);
        Assert.Equal(3500L, (await kit.BalanceOfAsync(client)).Amount.MinorUnits);
    }

    [Fact]
    public async Task Un_abono_a_un_cliente_archivado_tambien_se_acepta()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")), SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, 1000)));
        await kit.PushOkAsync(kit.Owner, SyncOp("client.archive", client));

        var results = await kit.PushOkAsync(beto, SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, 400)));

        Assert.Equal("applied", Status(results[0]));
        Assert.Equal(600L, (await kit.BalanceOfAsync(client)).Amount.MinorUnits);
    }

    [Fact]
    public async Task El_pull_entrega_el_cliente_archivado_y_el_fiado_nuevo_al_otro_dispositivo()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        var fiado = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        var cursor = (await kit.PullOkAsync(kit.Owner)).GetProperty("cursor").GetInt64();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.archive", client));
        await kit.PushOkAsync(beto, SyncOp("fiado.create", fiado, FiadoPayload(client, 2500)));

        var page = await kit.PullOkAsync(kit.Owner, cursor);

        var changes = page.GetProperty("changes").EnumerateArray().ToArray();
        Assert.Equal(["client", "fiado"], changes.Select(c => c.GetProperty("type").GetString()).ToArray());
        Assert.True(changes[0].GetProperty("entity").GetProperty("archived").GetBoolean());
        Assert.Equal(2500L, changes[1].GetProperty("entity").GetProperty("total").GetInt64());
    }

    [Fact]
    public async Task Archivar_y_fiar_en_el_mismo_lote_deja_el_cliente_archivado_con_su_fiado()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();

        var results = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", client, ClientPayload("Ana")),
            SyncOp("client.archive", client),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, 700)));

        Assert.All(results, r => Assert.Equal("applied", Status(r)));
        Assert.True((await kit.Host.Db.Clients.IgnoreQueryFilters().AsNoTracking().SingleAsync(c => c.Id == client)).Archived);
        Assert.Equal(700L, (await kit.BalanceOfAsync(client)).Amount.MinorUnits);
    }
}
