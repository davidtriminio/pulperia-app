using Microsoft.EntityFrameworkCore;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T181: el precio anterior de un producto y la fecha del cambio llegan al móvil por el pull (RF-90, D-24).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ProductPriceSyncTests(PostgresFixture postgres)
{
    private static object Product(string name, long price, string unit = "pound") => new { name, price, unit };

    private static async Task<System.Text.Json.JsonElement> PulledProduct(SyncKit kit, Guid id)
    {
        var page = await kit.PullOkAsync(kit.Owner);
        return page.GetProperty("changes").EnumerateArray()
            .Single(c => c.GetProperty("type").GetString() == "product").GetProperty("entity");
    }

    [Fact]
    public async Task Un_cambio_de_precio_sincronizado_deja_el_anterior_y_la_fecha_y_el_pull_los_entrega()
    {
        await using var kit = await StartAsync(postgres);
        var product = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("product.create", product, Product("Arroz", 2500)));

        await kit.PushOkAsync(kit.Owner, SyncOp("product.update", product, Product("Arroz", 3000), baseVersion: 1));

        var saved = await kit.Host.Db.Products.IgnoreQueryFilters().SingleAsync(p => p.Id == product);
        Assert.Equal((3000L, 2500L, Pulperia.Tests.Support.OperationKit.At.UtcDateTime), (saved.Price, saved.PreviousPrice, saved.PriceChangedAt));
        var pulled = await PulledProduct(kit, product);
        Assert.Equal((3000L, 2500L), (pulled.GetProperty("price").GetInt64(), pulled.GetProperty("previousPrice").GetInt64()));
        Assert.Equal(
            Pulperia.Tests.Support.OperationKit.At.UtcDateTime,
            pulled.GetProperty("priceChangedAt").GetDateTime().ToUniversalTime());
    }

    [Fact]
    public async Task Un_producto_sin_cambio_de_precio_viaja_con_los_dos_campos_en_nulo()
    {
        await using var kit = await StartAsync(postgres);
        var product = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("product.create", product, Product("Arroz", 2500)));

        var pulled = await PulledProduct(kit, product);

        Assert.Equal(System.Text.Json.JsonValueKind.Null, pulled.GetProperty("previousPrice").ValueKind);
        Assert.Equal(System.Text.Json.JsonValueKind.Null, pulled.GetProperty("priceChangedAt").ValueKind);
    }

    [Fact]
    public async Task Un_cambio_de_solo_nombre_o_unidad_no_toca_el_anterior_ni_la_fecha()
    {
        await using var kit = await StartAsync(postgres);
        var product = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("product.create", product, Product("Arroz", 2500)));
        await kit.PushOkAsync(kit.Owner, SyncOp("product.update", product, Product("Arroz", 3000), baseVersion: 1));

        await kit.PushOkAsync(kit.Owner, SyncOp("product.update", product, Product("Arroz grano largo", 3000, "kilo"), baseVersion: 2));

        var pulled = await PulledProduct(kit, product);
        Assert.Equal(("Arroz grano largo", "kilo", 3000L, 2500L, 3), (
            pulled.GetProperty("name").GetString(), pulled.GetProperty("unit").GetString(),
            pulled.GetProperty("price").GetInt64(), pulled.GetProperty("previousPrice").GetInt64(),
            pulled.GetProperty("version").GetInt32()));
    }

    [Fact]
    public async Task Volver_al_precio_de_antes_deja_como_anterior_el_que_se_dejo()
    {
        await using var kit = await StartAsync(postgres);
        var product = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("product.create", product, Product("Arroz", 2000)));
        await kit.PushOkAsync(kit.Owner, SyncOp("product.update", product, Product("Arroz", 2500), baseVersion: 1));
        await kit.PushOkAsync(kit.Owner, SyncOp("product.update", product, Product("Arroz", 2000), baseVersion: 2));

        var pulled = await PulledProduct(kit, product);

        Assert.Equal((2000L, 2500L), (pulled.GetProperty("price").GetInt64(), pulled.GetProperty("previousPrice").GetInt64()));
    }
}
