using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Ledger;
using Pulperia.Domain.Quantities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Domain;

public class SubtotalTests
{
    public static TheoryData<string> IntegerCases => SharedVectors.Names("subtotal-integer.json");
    public static TheoryData<string> TwoDecimalCases => SharedVectors.Names("subtotal-two-decimals.json");

    private static void AssertCase(string file, string name)
    {
        var c = SharedVectors.Get(file, name);
        var mode = AmountModes.FromId(c.Input.GetProperty("amountMode").GetString()!);
        var quantity = new Quantity(c.Input.GetProperty("quantityMilli").GetInt64());
        var unitPrice = new Money(c.Input.GetProperty("unitPrice").GetInt64());

        var subtotal = Subtotals.Of(mode, quantity, unitPrice);

        Assert.Equal(c.Expected.GetProperty("subtotal").GetInt64(), subtotal.MinorUnits);
    }

    [Fact]
    public void Hay_al_menos_15_casos_por_modo()
    {
        Assert.True(SharedVectors.Load("subtotal-integer.json").Count >= 15);
        Assert.True(SharedVectors.Load("subtotal-two-decimals.json").Count >= 15);
    }

    [Theory]
    [MemberData(nameof(IntegerCases))]
    public void Subtotal_con_montos_enteros_segun_los_vectores(string name) =>
        AssertCase("subtotal-integer.json", name);

    [Theory]
    [MemberData(nameof(TwoDecimalCases))]
    public void Subtotal_con_dos_decimales_segun_los_vectores(string name) =>
        AssertCase("subtotal-two-decimals.json", name);

    [Fact]
    public void Cada_modo_usa_su_propio_redondeo()
    {
        // 2.5 por L 5.00 son L 12.50: con enteros sube a L 13; con decimales queda igual.
        var quantity = new Quantity(2500);
        var price = new Money(500);

        Assert.Equal(new Money(1300), Subtotals.WholeLempira(quantity, price));
        Assert.Equal(new Money(1250), Subtotals.Centavo(quantity, price));
        Assert.Equal(new Money(1300), Subtotals.Of(AmountMode.Integer, quantity, price));
        Assert.Equal(new Money(1250), Subtotals.Of(AmountMode.TwoDecimals, quantity, price));
    }

    [Fact]
    public void La_mitad_siempre_sube_nunca_al_par()
    {
        // 0.5 por L 1.01 son 50.5 centavos: sube a 51, no baja a 50.
        Assert.Equal(new Money(51), Subtotals.Centavo(new Quantity(500), new Money(101)));
        // 1.5 por L 1.00 son L 1.50: sube a L 2; 0.5 por L 1.00 son L 0.50: sube a L 1.
        Assert.Equal(new Money(200), Subtotals.WholeLempira(new Quantity(1500), new Money(100)));
        Assert.Equal(new Money(100), Subtotals.WholeLempira(new Quantity(500), new Money(100)));
    }

    [Theory]
    [InlineData(0, 100)]
    [InlineData(-1000, 100)]
    [InlineData(1000, 0)]
    [InlineData(1000, -100)]
    public void Cantidad_o_precio_no_positivos_se_rechazan(long milli, long price)
    {
        Assert.Throws<ArgumentOutOfRangeException>(
            () => Subtotals.Centavo(new Quantity(milli), new Money(price)));
        Assert.Throws<ArgumentOutOfRangeException>(
            () => Subtotals.WholeLempira(new Quantity(milli), new Money(price)));
    }

    [Fact]
    public void Un_resultado_que_no_cabe_desborda_con_excepcion()
    {
        Assert.Throws<OverflowException>(
            () => Subtotals.Centavo(new Quantity(long.MaxValue), new Money(long.MaxValue)));
    }
}
