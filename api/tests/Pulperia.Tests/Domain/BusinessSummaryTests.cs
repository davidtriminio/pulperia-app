using System.Text.Json;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Ledger;
using Pulperia.Domain.Summary;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Domain;

public class BusinessSummaryTests
{
    private const string Vectors = "summary.json";

    public static TheoryData<string> Cases => SharedVectors.Names(Vectors);

    private static ClientBalance Client(string id, long balance, bool archived = false) =>
        new(id, new Balance(new Money(balance)), archived);

    private static List<ClientBalance> ClientsOf(JsonElement input) =>
        input.GetProperty("clients")
            .EnumerateArray()
            .Select(c => Client(
                c.GetProperty("id").GetString()!,
                c.GetProperty("balance").GetInt64(),
                c.GetProperty("archived").GetBoolean()))
            .ToList();

    [Fact]
    public void Hay_al_menos_15_casos() =>
        Assert.True(SharedVectors.Load(Vectors).Count >= 15);

    [Theory]
    [MemberData(nameof(Cases))]
    public void Resumen_segun_los_vectores_compartidos(string name)
    {
        var c = SharedVectors.Get(Vectors, name);

        var summary = Summaries.Summarize(ClientsOf(c.Input));

        Assert.Equal(c.Expected.GetProperty("debtTotal").GetInt64(), summary.DebtTotal.MinorUnits);
        Assert.Equal(c.Expected.GetProperty("creditTotal").GetInt64(), summary.CreditTotal.MinorUnits);
        Assert.Equal(
            c.Expected.GetProperty("topDebtorIds").EnumerateArray().Select(e => e.GetString()!).ToList(),
            summary.Debtors.Select(d => d.ClientId).ToList());
    }

    private static readonly List<ClientBalance> Sample =
    [
        Client("c-01", 12000), Client("c-02", -3000), Client("c-03", 0), Client("c-04", 8000),
        Client("c-05", 50000, archived: true), Client("c-06", -700, archived: true),
        Client("c-07", 8000), Client("c-08", -250), Client("c-09", 1),
    ];

    [Fact]
    public void El_orden_de_entrada_de_los_clientes_no_altera_el_resumen()
    {
        var expected = Summaries.Summarize(Sample);
        var random = new Random(7);

        for (var i = 0; i < 50; i++)
        {
            var summary = Summaries.Summarize(Sample.OrderBy(_ => random.Next()).ToList());

            Assert.Equal(expected.DebtTotal, summary.DebtTotal);
            Assert.Equal(expected.CreditTotal, summary.CreditTotal);
            Assert.Equal(
                expected.Debtors.Select(d => d.ClientId),
                summary.Debtors.Select(d => d.ClientId));
        }
    }

    [Fact]
    public void La_deuda_total_es_la_suma_de_la_deuda_de_la_lista()
    {
        var summary = Summaries.Summarize(Sample);

        var sum = summary.Debtors.Aggregate(Money.Zero, (total, d) => total + d.Debt);
        Assert.Equal(summary.DebtTotal, sum);
    }

    [Fact]
    public void La_lista_va_de_mayor_a_menor_y_desempata_por_id_ascendente()
    {
        var debtors = Summaries.Summarize(Sample).Debtors;

        for (var i = 1; i < debtors.Count; i++)
        {
            var byDebt = debtors[i - 1].Debt.CompareTo(debtors[i].Debt);
            Assert.True(byDebt >= 0);
            if (byDebt == 0)
            {
                Assert.True(string.CompareOrdinal(debtors[i - 1].ClientId, debtors[i].ClientId) < 0);
            }
        }
    }

    [Fact]
    public void El_desempate_es_ordinal_y_no_depende_de_la_cultura()
    {
        // "B" (66) va antes que "a" (97) en comparación ordinal; con cultura iría al revés.
        var summary = Summaries.Summarize([Client("a", 1000), Client("B", 1000)]);

        Assert.Equal(["B", "a"], summary.Debtors.Select(d => d.ClientId));
    }

    [Fact]
    public void Los_archivados_no_aparecen_ni_suman()
    {
        var summary = Summaries.Summarize(Sample);

        Assert.DoesNotContain(summary.Debtors, d => d.ClientId == "c-05");
        Assert.Equal(new Money(3250), summary.CreditTotal);
    }

    [Fact]
    public void Los_saldados_no_aparecen_en_la_lista() =>
        Assert.DoesNotContain(Summaries.Summarize(Sample).Debtors, d => d.ClientId == "c-03");

    [Fact]
    public void El_saldo_a_favor_no_resta_de_la_deuda_total()
    {
        var summary = Summaries.Summarize([Client("a", 5000), Client("b", -2000)]);

        Assert.Equal(new Money(5000), summary.DebtTotal);
        Assert.Equal(new Money(2000), summary.CreditTotal);
    }

    [Fact]
    public void Un_negocio_sin_clientes_tiene_un_resumen_vacio()
    {
        var summary = Summaries.Summarize([]);

        Assert.Equal(Money.Zero, summary.DebtTotal);
        Assert.Equal(Money.Zero, summary.CreditTotal);
        Assert.Empty(summary.Debtors);
    }
}
