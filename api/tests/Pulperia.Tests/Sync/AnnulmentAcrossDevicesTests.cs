using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Ledger;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T078: se anula un fiado en un dispositivo y otro tiene abonos suyos; los abonos se conservan (RF-47).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class AnnulmentAcrossDevicesTests(PostgresFixture postgres)
{
    private sealed record World(SyncKit Kit, SyncAccount Beto, Guid Client, Guid Fiado);

    /// <summary>Ana registró un fiado de 5000 que Beto, sin conexión, todavía no conoce.</summary>
    private async Task<World> Setup()
    {
        var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        var fiado = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", client, ClientPayload("Ana")),
            SyncOp("fiado.create", fiado, FiadoPayload(client, 5000)));
        return new World(kit, beto, client, fiado);
    }

    [Fact]
    public async Task Los_abonos_de_otro_dispositivo_se_conservan_y_el_saldo_queda_a_favor()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var firstPayment = Guid.CreateVersion7();
        var secondPayment = Guid.CreateVersion7();

        // La dueña anula el fiado; Beto, que no lo sabía, registró abonos sobre ese cliente.
        var annul = await w.Kit.PushOkAsync(w.Kit.Owner, SyncOp("fiado.annul", w.Fiado));
        var payments = await w.Kit.PushOkAsync(
            w.Beto,
            SyncOp("payment.create", firstPayment, PaymentPayload(w.Client, 2000)),
            SyncOp("payment.create", secondPayment, PaymentPayload(w.Client, 4000)));

        Assert.Equal("applied", Status(annul[0]));
        Assert.All(payments, r => Assert.Equal("applied", Status(r)));
        Assert.Equal(2, await w.Kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync(p => p.AnnulledAt == null));
        var balance = await w.Kit.BalanceOfAsync(w.Client);
        Assert.Equal((BalanceLabel.Credit, 6000L), (balance.Label, balance.Credit.MinorUnits));
    }

    [Fact]
    public async Task El_orden_de_llegada_no_cambia_el_resultado()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        // Ahora los abonos llegan antes que la anulación.
        await w.Kit.PushOkAsync(w.Beto, SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(w.Client, 2000)));
        await w.Kit.PushOkAsync(w.Kit.Owner, SyncOp("fiado.annul", w.Fiado));

        var balance = await w.Kit.BalanceOfAsync(w.Client);
        Assert.Equal((BalanceLabel.Credit, 2000L), (balance.Label, balance.Credit.MinorUnits));
    }

    [Fact]
    public async Task Anular_el_fiado_deja_su_autor_y_fecha_y_no_toca_los_abonos()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var payment = Guid.CreateVersion7();
        await w.Kit.PushOkAsync(w.Beto, SyncOp("payment.create", payment, PaymentPayload(w.Client, 2000)));

        await w.Kit.PushOkAsync(w.Kit.Owner, SyncOp("fiado.annul", w.Fiado));

        var fiado = await w.Kit.Host.Db.Fiados.IgnoreQueryFilters().SingleAsync(f => f.Id == w.Fiado);
        var saved = await w.Kit.Host.Db.Payments.IgnoreQueryFilters().SingleAsync(p => p.Id == payment);
        Assert.Equal((w.Kit.Owner.UserId, OperationKit.At.UtcDateTime), (fiado.AnnulledBy, fiado.AnnulledAt));
        Assert.Equal((w.Beto.UserId, 2000L, (DateTime?)null), (saved.CreatedBy, saved.Amount, saved.AnnulledAt));
    }

    [Fact]
    public async Task Un_empleado_no_puede_anular_el_fiado_y_el_saldo_no_cambia()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var attempt = await w.Kit.PushOkAsync(w.Beto, SyncOp("fiado.annul", w.Fiado));

        Assert.Equal("forbidden", Code(attempt[0]));
        Assert.Equal(5000L, (await w.Kit.BalanceOfAsync(w.Client)).Amount.MinorUnits);
    }
}
