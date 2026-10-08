using System.Reflection;
using Pulperia.Domain.Business;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Quantities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Domain;

public class MoneyAndQuantityTests
{
    private const string Vectors = "business-modes.json";

    public static TheoryData<string> AmountCases => SharedVectors.Names(Vectors, "validate_amount");
    public static TheoryData<string> QuantityCases => SharedVectors.Names(Vectors, "validate_quantity");

    // ---- modos

    [Fact]
    public void AmountMode_usa_los_mismos_ids_que_los_vectores()
    {
        Assert.Equal(AmountMode.Integer, AmountModes.FromId("integer"));
        Assert.Equal(AmountMode.TwoDecimals, AmountModes.FromId("two_decimals"));
        Assert.Equal("integer", AmountMode.Integer.Id());
        Assert.Equal("two_decimals", AmountMode.TwoDecimals.Id());
    }

    [Fact]
    public void QuantityMode_usa_los_mismos_ids_que_los_vectores()
    {
        Assert.Equal(QuantityMode.Integer, QuantityModes.FromId("integer"));
        Assert.Equal(QuantityMode.Fractional, QuantityModes.FromId("fractional"));
        Assert.Equal("integer", QuantityMode.Integer.Id());
        Assert.Equal("fractional", QuantityMode.Fractional.Id());
    }

    [Fact]
    public void Un_id_de_modo_desconocido_lanza_ArgumentException()
    {
        Assert.Throws<ArgumentException>(() => AmountModes.FromId("otro"));
        Assert.Throws<ArgumentException>(() => QuantityModes.FromId("otro"));
    }

    // ---- dinero con los vectores compartidos (RF-32, RF-36)

    [Fact]
    public void Hay_casos_de_monto_en_los_vectores() =>
        Assert.True(SharedVectors.Load(Vectors, "validate_amount").Count >= 10);

    [Theory]
    [MemberData(nameof(AmountCases))]
    public void Money_Parse_con_los_vectores(string name)
    {
        var c = SharedVectors.Get(Vectors, name);
        var mode = AmountModes.FromId(c.Input.GetProperty("amountMode").GetString()!);

        var result = Money.Parse(c.Input.GetProperty("text").GetString()!, mode);

        if (c.Expected.GetProperty("valid").GetBoolean())
        {
            Assert.True(result.IsValid);
            Assert.Equal(c.Expected.GetProperty("value").GetInt64(), result.Money!.Value.MinorUnits);
        }
        else
        {
            Assert.False(result.IsValid);
            Assert.Equal(c.Expected.GetProperty("error").GetString(), result.Error!.Value.Code());
        }
    }

    [Theory]
    [InlineData("")]
    [InlineData("abc")]
    [InlineData("12,50")]
    [InlineData("12.")]
    [InlineData(".5")]
    [InlineData("--1")]
    [InlineData("1e3")]
    [InlineData(" 12")]
    [InlineData("12 ")]
    [InlineData("12\n")]
    [InlineData("١٢")] // dígitos árabes: solo cuentan 0-9
    public void Money_Parse_de_texto_que_no_es_un_numero_se_rechaza_sin_excepcion(string text)
    {
        foreach (var mode in Enum.GetValues<AmountMode>())
        {
            var result = Money.Parse(text, mode);

            Assert.False(result.IsValid);
            Assert.Equal(AmountError.InvalidFormat, result.Error);
        }
    }

    [Fact]
    public void Money_Parse_de_un_numero_enorme_se_rechaza_sin_desbordar()
    {
        var result = Money.Parse("99999999999999999999999", AmountMode.TwoDecimals);

        Assert.False(result.IsValid);
        Assert.Equal(AmountError.InvalidFormat, result.Error);
    }

    [Fact]
    public void Los_codigos_de_error_de_monto_son_estables()
    {
        Assert.Equal("amount_not_positive", AmountError.NotPositive.Code());
        Assert.Equal("amount_not_whole", AmountError.NotWhole.Code());
        Assert.Equal("amount_too_many_decimals", AmountError.TooManyDecimals.Code());
        Assert.Equal("amount_invalid_format", AmountError.InvalidFormat.Code());
    }

    // ---- aritmética exacta

    [Fact]
    public void Money_suma_resta_y_niega_en_la_unidad_menor()
    {
        var a = new Money(1050);
        var b = new Money(250);

        Assert.Equal(new Money(1300), a + b);
        Assert.Equal(new Money(800), a - b);
        Assert.Equal(new Money(-1050), -a);
        Assert.Equal(Money.Zero, a - a);
    }

    [Fact]
    public void Money_distingue_cero_positivo_y_negativo()
    {
        Assert.True(Money.Zero.IsZero);
        Assert.True(new Money(1).IsPositive);
        Assert.True(new Money(-1).IsNegative);
        Assert.False(Money.Zero.IsPositive);
        Assert.False(Money.Zero.IsNegative);
    }

    [Fact]
    public void Money_se_compara_por_su_valor()
    {
        Assert.True(new Money(1) < new Money(2));
        Assert.True(new Money(2) <= new Money(2));
        Assert.True(new Money(3) > new Money(2));
        Assert.True(new Money(2) >= new Money(2));
        Assert.Equal(new Money(5), new Money(5));
        Assert.Equal(-1, new Money(1).CompareTo(new Money(2)));
    }

    [Fact]
    public void Sumar_centavos_es_exacto_sin_error_de_redondeo()
    {
        // 0.10 diez veces debe dar exactamente 1.00 (con double daría 0.9999...).
        var total = Money.Zero;
        for (var i = 0; i < 10; i++)
        {
            total += new Money(10);
        }

        Assert.Equal(new Money(100), total);
    }

    [Fact]
    public void Money_desborda_con_excepcion_y_no_en_silencio()
    {
        Assert.Throws<OverflowException>(() => new Money(long.MaxValue) + new Money(1));
    }

    // ---- cantidad con los vectores compartidos (RF-32, RF-35, RF-84)

    [Fact]
    public void Hay_casos_de_cantidad_en_los_vectores() =>
        Assert.True(SharedVectors.Load(Vectors, "validate_quantity").Count >= 20);

    [Theory]
    [MemberData(nameof(QuantityCases))]
    public void Quantity_Parse_con_los_vectores(string name)
    {
        var c = SharedVectors.Get(Vectors, name);
        var mode = QuantityModes.FromId(c.Input.GetProperty("quantityMode").GetString()!);

        var result = Quantity.Parse(c.Input.GetProperty("text").GetString()!, mode);

        if (c.Expected.GetProperty("valid").GetBoolean())
        {
            Assert.True(result.IsValid);
            Assert.Equal(c.Expected.GetProperty("value").GetInt64(), result.Quantity!.Value.Milli);
        }
        else
        {
            Assert.False(result.IsValid);
            Assert.Equal(c.Expected.GetProperty("error").GetString(), result.Error!.Value.Code());
        }
    }

    [Theory]
    [InlineData("")]
    [InlineData("abc")]
    [InlineData("1,5")]
    [InlineData("1.")]
    [InlineData(".5")]
    [InlineData("--1")]
    [InlineData("1e3")]
    [InlineData(" 2")]
    [InlineData("2 ")]
    [InlineData("2\n")]
    public void Quantity_Parse_de_texto_que_no_es_un_numero_se_rechaza_sin_excepcion(string text)
    {
        foreach (var mode in Enum.GetValues<QuantityMode>())
        {
            var result = Quantity.Parse(text, mode);

            Assert.False(result.IsValid);
            Assert.Equal(QuantityError.InvalidFormat, result.Error);
        }
    }

    [Fact]
    public void Quantity_Parse_de_un_numero_enorme_se_rechaza_sin_desbordar()
    {
        var result = Quantity.Parse("99999999999999999999999", QuantityMode.Fractional);

        Assert.False(result.IsValid);
        Assert.Equal(QuantityError.InvalidFormat, result.Error);
    }

    [Fact]
    public void Quantity_guarda_milesimas_y_sabe_si_es_entera()
    {
        Assert.Equal(250, Quantity.Parse("0.25", QuantityMode.Fractional).Quantity!.Value.Milli);
        Assert.True(new Quantity(2000).IsWhole);
        Assert.False(new Quantity(2500).IsWhole);
    }

    [Fact]
    public void Los_codigos_de_error_de_cantidad_son_estables()
    {
        Assert.Equal("quantity_not_positive", QuantityError.NotPositive.Code());
        Assert.Equal("quantity_not_whole", QuantityError.NotWhole.Code());
        Assert.Equal("quantity_too_many_decimals", QuantityError.TooManyDecimals.Code());
        Assert.Equal("quantity_invalid_format", QuantityError.InvalidFormat.Code());
    }

    // ---- principio 5: dinero exacto, sin double ni float en el dominio

    [Fact]
    public void El_dominio_no_usa_double_ni_float()
    {
        var domain = typeof(Money).Assembly;
        const BindingFlags all = BindingFlags.Public | BindingFlags.NonPublic |
                                 BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;
        var forbidden = new[] { typeof(double), typeof(float) };
        var offenders = new List<string>();

        foreach (var type in domain.GetTypes())
        {
            foreach (var field in type.GetFields(all))
            {
                if (forbidden.Contains(field.FieldType)) offenders.Add($"{type.Name}.{field.Name}");
            }
            foreach (var prop in type.GetProperties(all))
            {
                if (forbidden.Contains(prop.PropertyType)) offenders.Add($"{type.Name}.{prop.Name}");
            }
            foreach (var method in type.GetMethods(all))
            {
                if (forbidden.Contains(method.ReturnType)) offenders.Add($"{type.Name}.{method.Name}()");
                foreach (var p in method.GetParameters())
                {
                    if (forbidden.Contains(p.ParameterType)) offenders.Add($"{type.Name}.{method.Name}({p.Name})");
                }
            }
        }

        Assert.Empty(offenders);
    }
}
