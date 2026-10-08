using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T181: <c>product.update</c> guarda el precio anterior y la fecha del cambio (RF-90, D-24).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ProductPriceHistoryTests(PostgresFixture postgres)
{
    private static readonly DateTimeOffset Later = At.AddDays(3);

    private static Task<Pulperia.Application.Operations.OperationResult> Update(
        OperationKit kit, Guid id, string name, long price, string unit, int version, DateTimeOffset? at = null) =>
        kit.Applier.ApplyAsync(
            Op("product.update", id, new { name, price, unit }, baseVersion: version, at: at), kit.Owner);

    [Fact]
    public async Task Un_cambio_de_precio_deja_el_anterior_y_la_fecha_de_la_operacion()
    {
        await using var kit = await CreateAsync(postgres);
        var id = await kit.NewProductAsync("Arroz", 2000, "pound");

        Assert.True((await Update(kit, id, "Arroz", 2500, "pound", 1, Later)).IsApplied);

        var product = await kit.GetProduct(id);
        Assert.Equal((2500L, 2000L), (product.Price, product.PreviousPrice));
        Assert.Equal(Later.UtcDateTime, product.PriceChangedAt);
    }

    [Fact]
    public async Task Un_producto_recien_creado_no_tiene_precio_anterior()
    {
        await using var kit = await CreateAsync(postgres);
        var id = await kit.NewProductAsync();

        var product = await kit.GetProduct(id);

        Assert.Null(product.PreviousPrice);
        Assert.Null(product.PriceChangedAt);
    }

    [Fact]
    public async Task Un_cambio_de_solo_nombre_o_de_solo_unidad_o_el_mismo_precio_no_tocan_el_historial()
    {
        await using var kit = await CreateAsync(postgres);
        var id = await kit.NewProductAsync("Arroz", 2000, "pound");
        Assert.True((await Update(kit, id, "Arroz", 2500, "pound", 1, Later)).IsApplied);
        var before = await kit.GetProduct(id);

        Assert.True((await Update(kit, id, "Arroz grano largo", 2500, "pound", 2, Later.AddDays(1))).IsApplied);
        Assert.True((await Update(kit, id, "Arroz grano largo", 2500, "kilo", 3, Later.AddDays(2))).IsApplied);

        var after = await kit.GetProduct(id);
        Assert.Equal("Arroz grano largo", after.Name);
        Assert.Equal((before.PreviousPrice, before.PriceChangedAt), (after.PreviousPrice, after.PriceChangedAt));
        Assert.Equal(4, after.Version);
    }

    [Fact]
    public async Task Veinte_veinticinco_y_de_vuelta_a_veinte_deja_veinticinco_como_anterior()
    {
        await using var kit = await CreateAsync(postgres);
        var id = await kit.NewProductAsync("Arroz", 2000, "pound");

        Assert.True((await Update(kit, id, "Arroz", 2500, "pound", 1, Later)).IsApplied);
        Assert.True((await Update(kit, id, "Arroz", 2000, "pound", 2, Later.AddDays(1))).IsApplied);

        var product = await kit.GetProduct(id);
        Assert.Equal((2000L, 2500L), (product.Price, product.PreviousPrice));
        Assert.Equal(Later.AddDays(1).UtcDateTime, product.PriceChangedAt);
    }

    [Fact]
    public async Task Un_cambio_rechazado_por_conflicto_de_version_no_toca_el_historial()
    {
        await using var kit = await CreateAsync(postgres);
        var id = await kit.NewProductAsync("Arroz", 2000, "pound");

        var stale = await Update(kit, id, "Arroz", 9999, "pound", 7, Later);

        Assert.Equal("version_conflict", stale.Code);
        var product = await kit.GetProduct(id);
        Assert.Equal((2000L, null), (product.Price, product.PreviousPrice));
        Assert.Null(product.PriceChangedAt);
    }

    [Fact]
    public async Task Cambiar_el_precio_no_toca_los_items_de_fiado_ya_registrados()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var productId = await kit.NewProductAsync("Arroz", 2000, "pound");
        var fiadoId = Guid.CreateVersion7();
        Assert.True((await kit.Applier.ApplyAsync(
            Op("fiado.create", fiadoId, FiadoPayload(clientId, 2000, Item(unitPrice: 2000, productId: productId))),
            kit.Owner)).IsApplied);

        Assert.True((await Update(kit, productId, "Arroz", 3000, "pound", 1, Later)).IsApplied);

        var item = Assert.Single(await kit.GetItems(fiadoId));
        Assert.Equal((2000L, 2000L), (item.UnitPrice, item.Subtotal));
    }
}
