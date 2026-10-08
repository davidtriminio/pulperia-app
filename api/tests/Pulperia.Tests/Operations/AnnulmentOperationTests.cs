using Pulperia.Domain.Ledger;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T060: anulación idempotente de fiados y abonos contra PostgreSQL real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class AnnulmentOperationTests(PostgresFixture postgres)
{
    private static readonly DateTimeOffset Later = At.AddDays(1);

    private static async Task<Guid> NewFiado(OperationKit kit, Guid clientId, long total = 2500)
    {
        var id = Guid.CreateVersion7();
        var result = await kit.Applier.ApplyAsync(
            Op("fiado.create", id, FiadoPayload(clientId, total, Item(unitPrice: total))), kit.Owner);
        return result.IsApplied ? id : throw new InvalidOperationException(result.Code);
    }

    private static async Task<Guid> NewPayment(OperationKit kit, Guid clientId, long amount = 1000)
    {
        var id = Guid.CreateVersion7();
        var result = await kit.Applier.ApplyAsync(Op("payment.create", id, PaymentPayload(clientId, amount)), kit.Owner);
        return result.IsApplied ? id : throw new InvalidOperationException(result.Code);
    }

    // ---- fiado

    [Fact]
    public async Task Anular_un_fiado_guarda_usuario_y_fecha_y_conserva_el_registro_y_sus_items()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = await NewFiado(kit, clientId);

        var result = await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId, at: Later), kit.Owner);

        Assert.True(result.IsApplied, result.Code);
        var fiado = await kit.GetFiado(fiadoId);
        Assert.Equal((Later.UtcDateTime, kit.OwnerId), (fiado.AnnulledAt, fiado.AnnulledBy));
        Assert.Equal((2500L, kit.OwnerId), (fiado.Total, fiado.CreatedBy));
        Assert.Single(await kit.GetItems(fiadoId));
    }

    [Fact]
    public async Task Un_fiado_anulado_deja_de_contar_en_el_saldo()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = await NewFiado(kit, clientId, 2500);
        await NewFiado(kit, clientId, 1000);

        await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId, at: Later), kit.Owner);

        Assert.Equal(1000, (await kit.BalanceOf(clientId)).Amount.MinorUnits);
    }

    [Fact]
    public async Task Anular_dos_veces_el_mismo_fiado_no_cambia_nada_ni_falla()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = await NewFiado(kit, clientId);
        await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId, at: Later), kit.Owner);

        var second = await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId, at: Later.AddDays(5)), kit.Owner);

        Assert.True(second.IsApplied, second.Code);
        var fiado = await kit.GetFiado(fiadoId);
        Assert.Equal((Later.UtcDateTime, kit.OwnerId), (fiado.AnnulledAt, fiado.AnnulledBy));
    }

    [Fact]
    public async Task Anular_un_fiado_inexistente_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(Op("fiado.annul", Guid.CreateVersion7()), kit.Owner);

        Assert.Equal("fiado_not_found", result.Code);
    }

    [Fact]
    public async Task Anular_un_fiado_con_abonos_de_otro_dispositivo_los_conserva_y_deja_saldo_a_favor()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = await NewFiado(kit, clientId, 2500);
        var paymentId = await NewPayment(kit, clientId, 1000);

        await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId, at: Later), kit.Owner);

        Assert.Null((await kit.GetPayment(paymentId)).AnnulledAt);
        var balance = await kit.BalanceOf(clientId);
        Assert.Equal((BalanceLabel.Credit, 1000L), (balance.Label, balance.Credit.MinorUnits));
    }

    // ---- abono

    [Fact]
    public async Task Anular_un_abono_guarda_usuario_y_fecha_y_restituye_la_deuda()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        await NewFiado(kit, clientId, 2500);
        var paymentId = await NewPayment(kit, clientId, 1000);
        Assert.Equal(1500, (await kit.BalanceOf(clientId)).Amount.MinorUnits);

        var result = await kit.Applier.ApplyAsync(Op("payment.annul", paymentId, at: Later), kit.Owner);

        Assert.True(result.IsApplied, result.Code);
        var payment = await kit.GetPayment(paymentId);
        Assert.Equal((Later.UtcDateTime, kit.OwnerId, 1000L), (payment.AnnulledAt, payment.AnnulledBy, payment.Amount));
        Assert.Equal(2500, (await kit.BalanceOf(clientId)).Amount.MinorUnits);
    }

    [Fact]
    public async Task Anular_dos_veces_el_mismo_abono_no_cambia_nada_ni_falla()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var paymentId = await NewPayment(kit, clientId);
        await kit.Applier.ApplyAsync(Op("payment.annul", paymentId, at: Later), kit.Owner);

        var second = await kit.Applier.ApplyAsync(Op("payment.annul", paymentId, at: Later.AddDays(5)), kit.Owner);

        Assert.True(second.IsApplied, second.Code);
        var payment = await kit.GetPayment(paymentId);
        Assert.Equal((Later.UtcDateTime, kit.OwnerId), (payment.AnnulledAt, payment.AnnulledBy));
    }

    [Fact]
    public async Task Anular_un_abono_inexistente_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(Op("payment.annul", Guid.CreateVersion7()), kit.Owner);

        Assert.Equal("payment_not_found", result.Code);
    }

    [Fact]
    public async Task Un_id_de_fiado_no_sirve_para_anular_un_abono_ni_al_reves()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = await NewFiado(kit, clientId);
        var paymentId = await NewPayment(kit, clientId);

        var fiadoAsPayment = await kit.Applier.ApplyAsync(Op("payment.annul", fiadoId), kit.Owner);
        var paymentAsFiado = await kit.Applier.ApplyAsync(Op("fiado.annul", paymentId), kit.Owner);

        Assert.Equal("payment_not_found", fiadoAsPayment.Code);
        Assert.Equal("fiado_not_found", paymentAsFiado.Code);
        Assert.Null((await kit.GetFiado(fiadoId)).AnnulledAt);
    }

    [Fact]
    public async Task No_existen_operaciones_para_editar_ni_borrar_un_fiado_o_un_abono()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = await NewFiado(kit, clientId);

        foreach (var type in new[] { "fiado.update", "fiado.delete", "payment.update", "payment.delete" })
        {
            var result = await kit.Applier.ApplyAsync(Op(type, fiadoId), kit.Owner);
            Assert.Equal("unknown_operation", result.Code);
        }
    }
}
