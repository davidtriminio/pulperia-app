using System.Text.Json;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Catalog;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Domain;

public class PriceChangeTests
{
    private const string Vectors = "price-change.json";

    public static TheoryData<string> Cases => SharedVectors.Names(Vectors);

    private static PriceHistory History(JsonElement previous, JsonElement changedAt) =>
        new(
            previous.ValueKind == JsonValueKind.Null ? null : new Money(previous.GetInt64()),
            changedAt.ValueKind == JsonValueKind.Null
                ? null
                : DateTimeOffset.Parse(changedAt.GetString()!).UtcDateTime);

    [Fact]
    public void Hay_al_menos_12_casos() =>
        Assert.True(SharedVectors.Load(Vectors).Count >= 12);

    [Theory]
    [MemberData(nameof(Cases))]
    public void Precio_anterior_segun_los_vectores_compartidos(string name)
    {
        var c = SharedVectors.Get(Vectors, name);

        var result = PriceChanges.Apply(
            new Money(c.Input.GetProperty("current_price").GetInt64()),
            History(c.Input.GetProperty("previous_price"), c.Input.GetProperty("price_changed_at")),
            new Money(c.Input.GetProperty("new_price").GetInt64()),
            DateTimeOffset.Parse(c.Input.GetProperty("at").GetString()!));

        var expected = History(c.Expected.GetProperty("previous_price"), c.Expected.GetProperty("price_changed_at"));
        Assert.Equal(expected.PreviousPrice, result.PreviousPrice);
        Assert.Equal(expected.ChangedAt, result.ChangedAt);
        Assert.True(result.ChangedAt is null || result.ChangedAt.Value.Kind == DateTimeKind.Utc);
    }

    [Fact]
    public void Dos_cambios_en_cadena_dejan_siempre_el_ultimo_anterior()
    {
        var history = new PriceHistory();
        var price = new Money(2000);
        foreach (var next in new long[] { 2500, 2000, 3000 })
        {
            history = PriceChanges.Apply(price, history, new Money(next), new DateTimeOffset(2026, 10, 5, 10, 0, 0, TimeSpan.Zero));
            price = new Money(next);
        }

        Assert.Equal(new Money(2000), history.PreviousPrice);
    }

    [Fact]
    public void La_fecha_se_guarda_en_UTC_aunque_llegue_con_otra_zona()
    {
        var result = PriceChanges.Apply(
            new Money(100),
            new PriceHistory(),
            new Money(200),
            DateTimeOffset.Parse("2026-10-05T08:30:00-06:00"));

        Assert.Equal(new DateTime(2026, 10, 5, 14, 30, 0, DateTimeKind.Utc), result.ChangedAt);
        Assert.Equal(DateTimeKind.Utc, result.ChangedAt!.Value.Kind);
    }
}
