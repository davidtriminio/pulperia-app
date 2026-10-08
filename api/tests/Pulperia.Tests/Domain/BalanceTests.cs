using System.Text.Json;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Domain;

public class BalanceTests
{
    private const string Vectors = "balance.json";

    public static TheoryData<string> Cases => SharedVectors.Names(Vectors);

    private static List<LedgerMovement> MovementsOf(JsonElement input) =>
        input.GetProperty("movements")
            .EnumerateArray()
            .Select(m => new LedgerMovement(
                m.GetProperty("type").GetString() == "fiado" ? MovementKind.Fiado : MovementKind.Payment,
                new Money(m.GetProperty("amount").GetInt64()),
                m.GetProperty("annulled").GetBoolean()))
            .ToList();

    private static LedgerMovement Fiado(long amount, bool annulled = false) =>
        new(MovementKind.Fiado, new Money(amount), annulled);

    private static LedgerMovement Payment(long amount, bool annulled = false) =>
        new(MovementKind.Payment, new Money(amount), annulled);

    [Fact]
    public void Hay_al_menos_15_casos() =>
        Assert.True(SharedVectors.Load(Vectors).Count >= 15);

    [Theory]
    [MemberData(nameof(Cases))]
    public void Saldo_segun_los_vectores_compartidos(string name)
    {
        var c = SharedVectors.Get(Vectors, name);

        var balance = Balances.Compute(MovementsOf(c.Input));

        Assert.Equal(c.Expected.GetProperty("balance").GetInt64(), balance.Amount.MinorUnits);
        Assert.Equal(c.Expected.GetProperty("label").GetString(), balance.Label.Id());
    }

    [Fact]
    public void El_orden_de_los_movimientos_no_altera_el_saldo()
    {
        var movements = new List<LedgerMovement>
        {
            Fiado(1500), Fiado(2500), Payment(1000), Fiado(4000, annulled: true),
            Payment(700), Fiado(999), Payment(300, annulled: true),
        };
        var expected = Balances.Compute(movements);
        var random = new Random(42);

        for (var i = 0; i < 50; i++)
        {
            var shuffled = movements.OrderBy(_ => random.Next()).ToList();

            Assert.Equal(expected.Amount, Balances.Compute(shuffled).Amount);
            Assert.Equal(expected.Label, Balances.Compute(shuffled).Label);
        }
    }

    [Fact]
    public void Anadir_un_movimiento_anulado_nunca_cambia_el_saldo()
    {
        var baseline = new List<LedgerMovement> { Fiado(5000), Payment(2000) };
        var expected = Balances.Compute(baseline).Amount;

        Assert.Equal(expected, Balances.Compute([.. baseline, Fiado(123456, annulled: true)]).Amount);
        Assert.Equal(expected, Balances.Compute([.. baseline, Payment(98765, annulled: true)]).Amount);
    }

    [Fact]
    public void Anular_un_movimiento_es_lo_mismo_que_quitarlo()
    {
        var withAnnulled = new[] { Fiado(5000), Fiado(3000, annulled: true), Payment(1000) };
        var without = new[] { Fiado(5000), Payment(1000) };

        Assert.Equal(Balances.Compute(without).Amount, Balances.Compute(withAnnulled).Amount);
    }

    [Fact]
    public void Un_fiado_sube_el_saldo_y_un_abono_lo_baja_exactamente_por_su_monto()
    {
        var baseline = new List<LedgerMovement> { Fiado(10000) };
        var before = Balances.Compute(baseline).Amount;

        Assert.Equal(before + new Money(750), Balances.Compute([.. baseline, Fiado(750)]).Amount);
        Assert.Equal(before - new Money(750), Balances.Compute([.. baseline, Payment(750)]).Amount);
    }

    [Theory]
    [InlineData(5000, BalanceLabel.Debt)]
    [InlineData(-1, BalanceLabel.Credit)]
    [InlineData(0, BalanceLabel.Settled)]
    public void La_etiqueta_coincide_con_el_signo_del_saldo(long minor, BalanceLabel expected) =>
        Assert.Equal(expected, new Balance(new Money(minor)).Label);

    [Fact]
    public void Deuda_y_saldo_a_favor_nunca_son_negativos()
    {
        var debt = new Balance(new Money(4200));
        var credit = new Balance(new Money(-3000));
        var settled = new Balance(Money.Zero);

        Assert.Equal(new Money(4200), debt.Debt);
        Assert.Equal(Money.Zero, debt.Credit);
        Assert.Equal(Money.Zero, credit.Debt);
        Assert.Equal(new Money(3000), credit.Credit);
        Assert.Equal(Money.Zero, settled.Debt);
        Assert.Equal(Money.Zero, settled.Credit);
    }

    [Fact]
    public void Un_abono_mayor_que_la_deuda_deja_saldo_a_favor_y_se_conserva_aunque_el_fiado_se_anule()
    {
        // RF-39 y RF-47: el fiado se anula en otro dispositivo y el abono sigue vigente.
        var balance = Balances.Compute([Fiado(5000, annulled: true), Payment(3000)]);

        Assert.Equal(BalanceLabel.Credit, balance.Label);
        Assert.Equal(new Money(3000), balance.Credit);
    }

    [Fact]
    public void Los_ids_de_etiqueta_son_estables()
    {
        Assert.Equal("debt", BalanceLabel.Debt.Id());
        Assert.Equal("credit", BalanceLabel.Credit.Id());
        Assert.Equal("settled", BalanceLabel.Settled.Id());
    }
}
