using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Ledger;
using Pulperia.Domain.Quantities;

namespace Pulperia.Tests.Domain;

/// <summary>
/// Los mismos casos que el móvil (T020 y T021): validar un fiado y un abono debe dar
/// lo mismo en las dos plataformas.
/// </summary>
public class FiadoAndPaymentValidationTests
{
    private static FiadoItemDraft Item(
        string description = "Arroz",
        string? productId = null,
        long quantityMilli = 1000,
        long unitPrice = 2500,
        SaleUnit unit = SaleUnit.Unit) =>
        new(description, productId, new Quantity(quantityMilli), new Money(unitPrice), unit);

    private static FiadoValidationResult Validate(
        FiadoDraft draft,
        AmountMode amountMode = AmountMode.TwoDecimals,
        QuantityMode quantityMode = QuantityMode.Fractional) =>
        FiadoValidator.Validate(draft, amountMode, quantityMode);

    private static List<(int?, FiadoField, string)> IssuesOf(FiadoValidationResult result) =>
        ((InvalidFiado)result).Issues.Select(i => (i.ItemIndex, i.Field, i.Code)).ToList();

    // ---- fiado con ítems (RF-28)

    [Fact]
    public void Cada_item_conserva_descripcion_producto_cantidad_precio_y_unidad()
    {
        var result = Validate(new FiadoWithItems([
            Item("Arroz", "p-1", 2000, 1500, SaleUnit.Pound),
            Item("Queso suelto", null, 500, 3000),
        ]));

        var valid = Assert.IsType<ValidFiado>(result);
        Assert.Equal(2, valid.Items.Count);
        Assert.Equal("Arroz", valid.Items[0].Description);
        Assert.Equal("p-1", valid.Items[0].ProductId);
        Assert.Equal(new Quantity(2000), valid.Items[0].Quantity);
        Assert.Equal(new Money(1500), valid.Items[0].UnitPrice);
        Assert.Equal(SaleUnit.Pound, valid.Items[0].Unit);
        Assert.Equal("Queso suelto", valid.Items[1].Description);
        Assert.Null(valid.Items[1].ProductId);
        Assert.Equal(new Quantity(500), valid.Items[1].Quantity);
        Assert.Equal(new Money(3000), valid.Items[1].UnitPrice);
        Assert.Equal(SaleUnit.Unit, valid.Items[1].Unit);
    }

    [Fact]
    public void El_total_es_la_suma_de_los_subtotales_de_los_items()
    {
        var result = Validate(new FiadoWithItems([
            Item(quantityMilli: 2000, unitPrice: 1500),
            Item(quantityMilli: 500, unitPrice: 3000),
        ]));

        var valid = Assert.IsType<ValidFiado>(result);
        Assert.Equal(new Money(3000), valid.Items[0].Subtotal);
        Assert.Equal(new Money(1500), valid.Items[1].Subtotal);
        Assert.Equal(new Money(4500), valid.Total);
    }

    [Fact]
    public void Con_montos_de_2_decimales_el_subtotal_se_redondea_al_centavo()
    {
        var result = Validate(new FiadoWithItems([Item(quantityMilli: 333, unitPrice: 1250)]));

        var valid = Assert.IsType<ValidFiado>(result);
        Assert.Equal(new Money(416), valid.Items.Single().Subtotal);
        Assert.Equal(new Money(416), valid.Total);
    }

    [Fact]
    public void Con_montos_enteros_el_subtotal_se_redondea_al_lempira()
    {
        var result = Validate(
            new FiadoWithItems([Item(quantityMilli: 250, unitPrice: 3000)]),
            AmountMode.Integer);

        var valid = Assert.IsType<ValidFiado>(result);
        Assert.Equal(new Money(800), valid.Items.Single().Subtotal);
        Assert.Equal(new Money(800), valid.Total);
    }

    // ---- fiado solo con monto total (RF-29)

    [Fact]
    public void Un_fiado_solo_con_monto_total_se_acepta_sin_items()
    {
        var result = Validate(new FiadoTotalOnly(new Money(5000)));

        var valid = Assert.IsType<ValidFiado>(result);
        Assert.Equal(new Money(5000), valid.Total);
        Assert.Empty(valid.Items);
    }

    // ---- fiado vacío (RF-33)

    [Fact]
    public void Sin_items_se_rechaza()
    {
        Assert.Equal(
            [(null, FiadoField.Fiado, "fiado_empty")],
            IssuesOf(Validate(new FiadoWithItems([]))));
    }

    [Fact]
    public void Sin_monto_total_se_rechaza()
    {
        Assert.Equal(
            [(null, FiadoField.Fiado, "fiado_empty")],
            IssuesOf(Validate(new FiadoTotalOnly(null))));
    }

    // ---- valores en cero o negativos (RF-32)

    [Fact]
    public void Cantidad_cero() =>
        Assert.Equal(
            [(0, FiadoField.Quantity, "quantity_not_positive")],
            IssuesOf(Validate(new FiadoWithItems([Item(quantityMilli: 0)]))));

    [Fact]
    public void Cantidad_negativa() =>
        Assert.Equal(
            [(0, FiadoField.Quantity, "quantity_not_positive")],
            IssuesOf(Validate(new FiadoWithItems([Item(quantityMilli: -500)]))));

    [Fact]
    public void Precio_unitario_cero() =>
        Assert.Equal(
            [(0, FiadoField.UnitPrice, "amount_not_positive")],
            IssuesOf(Validate(new FiadoWithItems([Item(unitPrice: 0)]))));

    [Fact]
    public void Precio_unitario_negativo() =>
        Assert.Equal(
            [(0, FiadoField.UnitPrice, "amount_not_positive")],
            IssuesOf(Validate(new FiadoWithItems([Item(unitPrice: -100)]))));

    [Fact]
    public void Monto_total_cero() =>
        Assert.Equal(
            [(null, FiadoField.Total, "amount_not_positive")],
            IssuesOf(Validate(new FiadoTotalOnly(new Money(0)))));

    [Fact]
    public void Monto_total_negativo() =>
        Assert.Equal(
            [(null, FiadoField.Total, "amount_not_positive")],
            IssuesOf(Validate(new FiadoTotalOnly(new Money(-5000)))));

    [Fact]
    public void Se_reportan_todos_los_problemas_item_por_item_y_campo_por_campo()
    {
        var result = Validate(new FiadoWithItems([
            Item(quantityMilli: 0, unitPrice: 0),
            Item(),
            Item(quantityMilli: -1, unitPrice: 2500),
        ]));

        Assert.Equal(
            [
                (0, FiadoField.Quantity, "quantity_not_positive"),
                (0, FiadoField.UnitPrice, "amount_not_positive"),
                (2, FiadoField.Quantity, "quantity_not_positive"),
            ],
            IssuesOf(result));
    }

    [Fact]
    public void Un_item_cuyo_subtotal_redondea_a_cero_se_rechaza()
    {
        var result = Validate(
            new FiadoWithItems([Item(quantityMilli: 1, unitPrice: 100)]),
            AmountMode.Integer);

        Assert.Equal(
            [(0, FiadoField.Subtotal, "amount_not_positive")],
            IssuesOf(result));
    }

    // ---- modos del negocio (RF-35, RF-36)

    [Fact]
    public void Montos_enteros_un_precio_con_centavos_se_rechaza() =>
        Assert.Equal(
            [(0, FiadoField.UnitPrice, "amount_not_whole")],
            IssuesOf(Validate(new FiadoWithItems([Item(unitPrice: 1250)]), AmountMode.Integer)));

    [Fact]
    public void Montos_enteros_un_monto_total_con_centavos_se_rechaza() =>
        Assert.Equal(
            [(null, FiadoField.Total, "amount_not_whole")],
            IssuesOf(Validate(new FiadoTotalOnly(new Money(1250)), AmountMode.Integer)));

    [Fact]
    public void Cantidades_enteras_una_cantidad_con_fraccion_se_rechaza() =>
        Assert.Equal(
            [(0, FiadoField.Quantity, "quantity_not_whole")],
            IssuesOf(Validate(
                new FiadoWithItems([Item(quantityMilli: 2500)]),
                quantityMode: QuantityMode.Integer)));

    [Fact]
    public void Dos_decimales_y_cantidades_fraccionarias_aceptan_centavos_y_fracciones()
    {
        var result = Validate(new FiadoWithItems([Item(quantityMilli: 2500, unitPrice: 1250)]));

        Assert.IsType<ValidFiado>(result);
    }

    [Fact]
    public void Montos_enteros_con_cantidades_fraccionarias_es_una_combinacion_valida()
    {
        var result = Validate(
            new FiadoWithItems([Item(quantityMilli: 250, unitPrice: 3000)]),
            AmountMode.Integer);

        Assert.IsType<ValidFiado>(result);
    }

    [Fact]
    public void La_descripcion_no_se_valida_porque_la_spec_no_define_regla()
    {
        var result = Validate(new FiadoWithItems([Item(description: "")]));

        Assert.IsType<ValidFiado>(result);
    }

    // ---- abono (RF-37, RF-38, RF-39)

    [Fact]
    public void Un_abono_positivo_se_acepta_y_se_conserva()
    {
        var result = PaymentValidator.Validate(new Money(3000), AmountMode.TwoDecimals);

        Assert.Equal(new Money(3000), Assert.IsType<ValidPayment>(result).Amount);
    }

    [Fact]
    public void El_abono_minimo_un_centavo_se_acepta_con_2_decimales() =>
        Assert.IsType<ValidPayment>(PaymentValidator.Validate(new Money(1), AmountMode.TwoDecimals));

    [Fact]
    public void Un_abono_grande_se_acepta()
    {
        var result = PaymentValidator.Validate(new Money(99999999000), AmountMode.TwoDecimals);

        Assert.Equal(new Money(99999999000), Assert.IsType<ValidPayment>(result).Amount);
    }

    [Fact]
    public void Con_montos_enteros_un_lempira_entero_se_acepta() =>
        Assert.IsType<ValidPayment>(PaymentValidator.Validate(new Money(5000), AmountMode.Integer));

    [Fact]
    public void Un_abono_mayor_que_la_deuda_nunca_se_rechaza_por_validacion()
    {
        // La validación no conoce el saldo: un abono mayor que la deuda deja saldo a favor (RF-39).
        Assert.IsType<ValidPayment>(PaymentValidator.Validate(new Money(12000), AmountMode.TwoDecimals));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-3000)]
    [InlineData(-1)]
    public void Un_abono_no_positivo_se_rechaza(long minor)
    {
        var result = PaymentValidator.Validate(new Money(minor), AmountMode.TwoDecimals);

        var invalid = Assert.IsType<InvalidPayment>(result);
        Assert.Equal(AmountError.NotPositive, invalid.Error);
        Assert.Equal("amount_not_positive", invalid.Error.Code());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-100)]
    [InlineData(-5000)]
    public void Cero_y_negativo_se_rechazan_tambien_con_montos_enteros(long minor)
    {
        var result = PaymentValidator.Validate(new Money(minor), AmountMode.Integer);

        Assert.Equal(AmountError.NotPositive, Assert.IsType<InvalidPayment>(result).Error);
    }

    [Theory]
    [InlineData(1250)]
    [InlineData(1)]
    [InlineData(101)]
    [InlineData(99)]
    public void Montos_enteros_un_abono_con_centavos_se_rechaza(long minor)
    {
        var result = PaymentValidator.Validate(new Money(minor), AmountMode.Integer);

        var invalid = Assert.IsType<InvalidPayment>(result);
        Assert.Equal(AmountError.NotWhole, invalid.Error);
        Assert.Equal("amount_not_whole", invalid.Error.Code());
    }

    [Fact]
    public void Dos_decimales_un_abono_con_centavos_se_acepta() =>
        Assert.IsType<ValidPayment>(PaymentValidator.Validate(new Money(1250), AmountMode.TwoDecimals));

    [Fact]
    public void Un_monto_no_positivo_se_rechaza_antes_que_la_regla_de_enteros()
    {
        var result = PaymentValidator.Validate(new Money(-150), AmountMode.Integer);

        Assert.Equal(AmountError.NotPositive, Assert.IsType<InvalidPayment>(result).Error);
    }

    // ---- regla común de monto

    [Fact]
    public void La_regla_comun_de_monto_devuelve_null_si_es_valido()
    {
        Assert.Null(AmountRules.Error(new Money(100), AmountMode.Integer));
        Assert.Null(AmountRules.Error(new Money(1), AmountMode.TwoDecimals));
        Assert.Equal(AmountError.NotWhole, AmountRules.Error(new Money(150), AmountMode.Integer));
        Assert.Equal(AmountError.NotPositive, AmountRules.Error(Money.Zero, AmountMode.TwoDecimals));
    }
}
