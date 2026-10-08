using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Ledger;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T077: dos dispositivos registran fiados y abonos del mismo cliente; se conservan todos (RF-54).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ConcurrentDevicesTests(PostgresFixture postgres)
{
    private static object[] Movements(Guid client, int count, long fiadoAmount, long paymentAmount) =>
        Enumerable.Range(0, count).SelectMany(_ => new[]
        {
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, fiadoAmount)),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, paymentAmount)),
        }).ToArray();

    [Fact]
    public async Task Tras_ambos_envios_el_saldo_es_la_suma_de_todos_los_movimientos()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));

        // Cada dispositivo trabajó sin conexión sobre el mismo cliente.
        var fromOwner = await kit.PushOkAsync(kit.Owner, Movements(client, 5, 1000, 300));
        var fromBeto = await kit.PushOkAsync(beto, Movements(client, 4, 2500, 700));

        Assert.All(fromOwner.Concat(fromBeto), r => Assert.Equal("applied", Status(r)));
        Assert.Equal(9, await kit.Host.Db.Fiados.IgnoreQueryFilters().CountAsync());
        Assert.Equal(9, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
        var expected = 5 * 1000 + 4 * 2500 - (5 * 300 + 4 * 700);
        Assert.Equal((long)expected, (await kit.BalanceOfAsync(client)).Amount.MinorUnits);
    }

    [Fact]
    public async Task Los_envios_simultaneos_de_dos_dispositivos_conservan_todo_y_dejan_los_seq_sin_huecos()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));

        var both = await Task.WhenAll(
            kit.PushOkAsync(kit.Owner, Movements(client, 20, 1000, 300)),
            kit.PushOkAsync(beto, Movements(client, 20, 2500, 700)));

        Assert.All(both.SelectMany(r => r), r => Assert.Equal("applied", Status(r)));
        Assert.Equal(40, await kit.Host.Db.Fiados.IgnoreQueryFilters().CountAsync());
        Assert.Equal(40, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
        Assert.Equal(20 * 1000 + 20 * 2500 - (20 * 300 + 20 * 700), (await kit.BalanceOfAsync(client)).Amount.MinorUnits);
        // 1 cliente + 80 movimientos, numerados del 1 al 81 sin saltos ni repetidos.
        var seqs = await kit.Host.Db.ChangeLog.IgnoreQueryFilters().OrderBy(c => c.Seq).Select(c => c.Seq).ToListAsync();
        Assert.Equal(Enumerable.Range(1, 81).Select(i => (long)i), seqs);
    }

    [Fact]
    public async Task Cada_movimiento_guarda_el_usuario_del_dispositivo_que_lo_envio()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));

        await Task.WhenAll(
            kit.PushOkAsync(kit.Owner, Movements(client, 3, 1000, 300)),
            kit.PushOkAsync(beto, Movements(client, 3, 2500, 700)));

        var byUser = await kit.Host.Db.Fiados.IgnoreQueryFilters()
            .GroupBy(f => f.CreatedBy).Select(g => new { g.Key, Count = g.Count() }).ToDictionaryAsync(x => x.Key, x => x.Count);
        Assert.Equal(3, byUser[kit.Owner.UserId]);
        Assert.Equal(3, byUser[beto.UserId]);
    }

    [Fact]
    public async Task Un_lote_que_espera_a_otro_no_pierde_ni_duplica_cambios_aunque_uno_traiga_rechazos()
    {
        await using var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        var withRejection = Movements(client, 5, 1000, 300).Append(SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(Guid.CreateVersion7(), 5))).ToArray();

        var both = await Task.WhenAll(
            kit.PushOkAsync(kit.Owner, withRejection),
            kit.PushOkAsync(beto, Movements(client, 5, 2500, 700)));

        Assert.Equal("client_not_found", Code(both[0][^1]));
        Assert.Equal(10, await kit.Host.Db.Fiados.IgnoreQueryFilters().CountAsync());
        Assert.Equal(5 * 1000 + 5 * 2500 - (5 * 300 + 5 * 700),
            (await kit.BalanceOfAsync(client)).Amount.MinorUnits);
    }
}
