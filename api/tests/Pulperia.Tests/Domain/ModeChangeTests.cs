using Pulperia.Domain.Business;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Domain;

public class ModeChangeTests
{
    private const string Vectors = "business-modes.json";

    public static TheoryData<string> AmountCases => SharedVectors.Names(Vectors, "change_amount_mode");
    public static TheoryData<string> QuantityCases => SharedVectors.Names(Vectors, "change_quantity_mode");

    private static void AssertExpected(VectorCaseResult actual, bool allowed, string? error)
    {
        Assert.Equal(allowed, actual.Allowed);
        Assert.Equal(error, actual.Error?.Code());
    }

    private sealed record VectorCaseResult(bool Allowed, ModeChangeError? Error);

    private static VectorCaseResult Of(ModeChangeResult result) =>
        new(result.Allowed, result.Error);

    [Fact]
    public void Hay_casos_de_cambio_de_modo_en_los_vectores()
    {
        Assert.True(SharedVectors.Load(Vectors, "change_amount_mode").Count >= 4);
        Assert.True(SharedVectors.Load(Vectors, "change_quantity_mode").Count >= 4);
    }

    [Theory]
    [MemberData(nameof(AmountCases))]
    public void Cambio_del_modo_de_montos_segun_los_vectores(string name)
    {
        var c = SharedVectors.Get(Vectors, name);
        var current = AmountModes.FromId(c.Input.GetProperty("current").GetString()!);
        var requested = AmountModes.FromId(c.Input.GetProperty("requested").GetString()!);

        var result = ModeChanges.ChangeAmountMode(current, requested);

        AssertExpected(
            Of(result),
            c.Expected.GetProperty("allowed").GetBoolean(),
            c.Expected.TryGetProperty("error", out var e) ? e.GetString() : null);
    }

    [Theory]
    [MemberData(nameof(QuantityCases))]
    public void Cambio_del_modo_de_cantidades_segun_los_vectores(string name)
    {
        var c = SharedVectors.Get(Vectors, name);
        var current = QuantityModes.FromId(c.Input.GetProperty("current").GetString()!);
        var requested = QuantityModes.FromId(c.Input.GetProperty("requested").GetString()!);

        var result = ModeChanges.ChangeQuantityMode(current, requested);

        AssertExpected(
            Of(result),
            c.Expected.GetProperty("allowed").GetBoolean(),
            c.Expected.TryGetProperty("error", out var e) ? e.GetString() : null);
    }

    [Fact]
    public void Montos_solo_se_puede_pasar_de_enteros_a_dos_decimales_RF8_RF9()
    {
        Assert.True(ModeChanges.ChangeAmountMode(AmountMode.Integer, AmountMode.TwoDecimals).Allowed);
        Assert.False(ModeChanges.ChangeAmountMode(AmountMode.TwoDecimals, AmountMode.Integer).Allowed);
    }

    [Fact]
    public void Cantidades_solo_se_puede_pasar_de_enteras_a_fraccionarias_RF8_RF9()
    {
        Assert.True(ModeChanges.ChangeQuantityMode(QuantityMode.Integer, QuantityMode.Fractional).Allowed);
        Assert.False(ModeChanges.ChangeQuantityMode(QuantityMode.Fractional, QuantityMode.Integer).Allowed);
    }

    [Fact]
    public void Pedir_el_mismo_modo_no_cambia_nada_y_se_permite()
    {
        foreach (var mode in Enum.GetValues<AmountMode>())
        {
            Assert.True(ModeChanges.ChangeAmountMode(mode, mode).Allowed);
        }
        foreach (var mode in Enum.GetValues<QuantityMode>())
        {
            Assert.True(ModeChanges.ChangeQuantityMode(mode, mode).Allowed);
        }
    }

    [Fact]
    public void El_rechazo_lleva_un_codigo_estable()
    {
        var result = ModeChanges.ChangeAmountMode(AmountMode.TwoDecimals, AmountMode.Integer);

        Assert.Equal(ModeChangeError.DowngradeNotAllowed, result.Error);
        Assert.Equal("mode_downgrade_not_allowed", result.Error!.Value.Code());
    }

    [Fact]
    public void Un_cambio_permitido_no_trae_error()
    {
        var result = ModeChanges.ChangeQuantityMode(QuantityMode.Integer, QuantityMode.Fractional);

        Assert.True(result.Allowed);
        Assert.Null(result.Error);
    }

    [Fact]
    public void Montos_y_cantidades_son_independientes()
    {
        // Pasar los montos a decimales no obliga a cambiar las cantidades, ni al revés.
        Assert.True(ModeChanges.ChangeAmountMode(AmountMode.Integer, AmountMode.TwoDecimals).Allowed);
        Assert.True(ModeChanges.ChangeQuantityMode(QuantityMode.Fractional, QuantityMode.Fractional).Allowed);
    }
}
