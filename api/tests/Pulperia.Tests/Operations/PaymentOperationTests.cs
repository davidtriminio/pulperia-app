using Pulperia.Domain.Business;
using Pulperia.Domain.Ledger;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T059: creación de abonos contra PostgreSQL real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class PaymentOperationTests(PostgresFixture postgres)
{
    private static Task<Pulperia.Application.Operations.OperationResult> Pay(
        OperationKit kit, Guid paymentId, object payload, bool asEmployee = true) =>
        kit.Applier.ApplyAsync(Op("payment.create", paymentId, payload), asEmployee ? kit.Employee : kit.Owner);

    [Fact]
    public async Task Un_abono_se_guarda_con_su_monto_fecha_y_el_usuario_que_lo_registro()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var byEmployee = Guid.CreateVersion7();
        var byOwner = Guid.CreateVersion7();

        Assert.True((await Pay(kit, byEmployee, PaymentPayload(clientId, 1500), asEmployee: true)).IsApplied);
        Assert.True((await Pay(kit, byOwner, PaymentPayload(clientId, 500), asEmployee: false)).IsApplied);

        var payment = await kit.GetPayment(byEmployee);
        Assert.Equal((kit.BusinessId, clientId, 1500L), (payment.BusinessId, payment.ClientId, payment.Amount));
        Assert.Equal(kit.EmployeeId, payment.CreatedBy);
        Assert.Equal(At.UtcDateTime, payment.OccurredAt);
        Assert.Null(payment.AnnulledAt);
        Assert.Equal(kit.OwnerId, (await kit.GetPayment(byOwner)).CreatedBy);
    }

    [Fact]
    public async Task Un_abono_mayor_que_la_deuda_se_acepta_y_deja_saldo_a_favor()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        Assert.True((await kit.Applier.ApplyAsync(
            Op("fiado.create", Guid.CreateVersion7(), FiadoPayload(clientId, 2500, Item())), kit.Owner)).IsApplied);

        var result = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(clientId, 10_000));

        Assert.True(result.IsApplied, result.Code);
        var balance = await kit.BalanceOf(clientId);
        Assert.Equal((BalanceLabel.Credit, 7500L), (balance.Label, balance.Credit.MinorUnits));
    }

    [Fact]
    public async Task Un_cliente_archivado_admite_abonos()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        Assert.True((await kit.Applier.ApplyAsync(Op("client.archive", clientId, baseVersion: 1), kit.Owner)).IsApplied);

        var result = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(clientId, 1500));

        Assert.True(result.IsApplied, result.Code);
        Assert.True((await kit.GetClient(clientId)).Archived);
    }

    [Fact]
    public async Task Un_abono_a_un_cliente_inexistente_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(Guid.CreateVersion7(), 1500));

        Assert.Equal("client_not_found", result.Code);
        Assert.Empty(kit.Db.Payments);
    }

    [Theory]
    [InlineData(0L)]
    [InlineData(-100L)]
    public async Task Un_monto_en_cero_o_negativo_se_rechaza(long amount)
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var result = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(clientId, amount));

        Assert.Equal("amount_not_positive", result.Code);
        Assert.Empty(kit.Db.Payments);
    }

    [Fact]
    public async Task Con_montos_enteros_un_abono_con_centavos_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres, AmountMode.Integer);
        var clientId = await kit.NewClientAsync();

        var result = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(clientId, 1550));

        Assert.Equal("amount_not_whole", result.Code);
    }

    [Fact]
    public async Task El_tope_del_monto_se_acepta_y_pasarlo_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var atLimit = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(clientId, LedgerLimits.MaxAmountMinorUnits));
        var over = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(clientId, LedgerLimits.MaxAmountMinorUnits + 1));
        var huge = await Pay(kit, Guid.CreateVersion7(), PaymentPayload(clientId, long.MaxValue));

        Assert.True(atLimit.IsApplied, atLimit.Code);
        Assert.Equal("amount_too_large", over.Code);
        Assert.Equal("amount_too_large", huge.Code);
        Assert.Single(kit.Db.Payments);
    }

    [Fact]
    public async Task Un_id_de_abono_repetido_se_rechaza_sin_tocar_el_original()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var id = Guid.CreateVersion7();
        Assert.True((await Pay(kit, id, PaymentPayload(clientId, 1500))).IsApplied);

        var again = await Pay(kit, id, PaymentPayload(clientId, 9999));

        Assert.Equal("entity_already_exists", again.Code);
        Assert.Equal(1500, (await kit.GetPayment(id)).Amount);
    }

    [Fact]
    public async Task Un_payload_sin_cliente_o_sin_monto_es_invalido()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var noClient = await Pay(kit, Guid.CreateVersion7(), new { amount = 1500 });
        var noAmount = await Pay(kit, Guid.CreateVersion7(), new { clientId });
        var textual = await Pay(kit, Guid.CreateVersion7(), new { clientId, amount = "15.00" });

        Assert.Equal("invalid_payload", noClient.Code);
        Assert.Equal("invalid_payload", noAmount.Code);
        Assert.Equal("invalid_payload", textual.Code);
    }
}
