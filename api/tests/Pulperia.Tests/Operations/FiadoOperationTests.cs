using Pulperia.Application.Operations;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Ledger;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T058: creación de fiados (con ítems y solo con monto) contra PostgreSQL real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class FiadoOperationTests(PostgresFixture postgres)
{
    private static Task<OperationResult> Create(
        OperationKit kit, Guid fiadoId, object payload, bool asEmployee = true) =>
        kit.Applier.ApplyAsync(Op("fiado.create", fiadoId, payload), asEmployee ? kit.Employee : kit.Owner);

    // ---- con ítems

    [Fact]
    public async Task Un_fiado_con_items_guarda_cada_item_con_el_precio_y_la_unidad_del_momento()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var productId = await kit.NewProductAsync("Arroz", 2500, "pound");
        var fiadoId = Guid.CreateVersion7();
        var itemId = Guid.CreateVersion7();

        var result = await Create(kit, fiadoId, FiadoPayload(clientId, 3750,
            Item(quantity: 1500, unitPrice: 2500, subtotal: 3750, productId: productId, unit: "kilo", id: itemId)));

        Assert.True(result.IsApplied, result.Code);
        var fiado = await kit.GetFiado(fiadoId);
        Assert.Equal((kit.BusinessId, clientId, 3750L), (fiado.BusinessId, fiado.ClientId, fiado.Total));
        Assert.Equal(At.UtcDateTime, fiado.OccurredAt);
        Assert.Null(fiado.AnnulledAt);
        var item = Assert.Single(await kit.GetItems(fiadoId));
        Assert.Equal((itemId, productId, "Arroz"), (item.Id, item.ProductId, item.Description));
        Assert.Equal((1500L, SaleUnit.Kilo, 2500L, 3750L), (item.Quantity, item.Unit, item.UnitPrice, item.Subtotal));
    }

    [Fact]
    public async Task Cada_fiado_guarda_el_usuario_que_lo_registro()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var byEmployee = Guid.CreateVersion7();
        var byOwner = Guid.CreateVersion7();

        Assert.True((await Create(kit, byEmployee, FiadoPayload(clientId, 2500, Item()), asEmployee: true)).IsApplied);
        Assert.True((await Create(kit, byOwner, FiadoPayload(clientId, 2500, Item()), asEmployee: false)).IsApplied);

        Assert.Equal(kit.EmployeeId, (await kit.GetFiado(byEmployee)).CreatedBy);
        Assert.Equal(kit.OwnerId, (await kit.GetFiado(byOwner)).CreatedBy);
    }

    [Fact]
    public async Task Un_item_libre_se_guarda_sin_producto()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = Guid.CreateVersion7();

        var result = await Create(kit, fiadoId, FiadoPayload(clientId, 1000,
            Item(quantity: 1000, unitPrice: 1000, description: "Fiado de la tienda", unit: "unit")));

        Assert.True(result.IsApplied, result.Code);
        var item = Assert.Single(await kit.GetItems(fiadoId));
        Assert.Null(item.ProductId);
        Assert.Equal(SaleUnit.Unit, item.Unit);
    }

    [Fact]
    public async Task El_total_es_la_suma_de_los_subtotales_de_varios_items()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = Guid.CreateVersion7();

        var result = await Create(kit, fiadoId, FiadoPayload(clientId, 6250,
            Item(quantity: 1000, unitPrice: 2500), Item(quantity: 1500, unitPrice: 2500, description: "Frijol")));

        Assert.True(result.IsApplied, result.Code);
        Assert.Equal(2, (await kit.GetItems(fiadoId)).Count);
    }

    [Fact]
    public async Task Cambiar_el_precio_del_producto_despues_no_altera_el_item_ya_registrado()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var productId = await kit.NewProductAsync("Arroz", 2500);
        var fiadoId = Guid.CreateVersion7();
        Assert.True((await Create(kit, fiadoId,
            FiadoPayload(clientId, 2500, Item(unitPrice: 2500, productId: productId)))).IsApplied);

        Assert.True((await kit.Applier.ApplyAsync(
            Op("product.update", productId, new { name = "Arroz", price = 9900, unit = "pound" }, baseVersion: 1),
            kit.Owner)).IsApplied);

        var item = Assert.Single(await kit.GetItems(fiadoId));
        Assert.Equal((2500L, 2500L), (item.UnitPrice, item.Subtotal));
        Assert.Equal(2500, (await kit.GetFiado(fiadoId)).Total);
    }

    // ---- solo con monto

    [Fact]
    public async Task Un_fiado_solo_con_monto_se_acepta_sin_items()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = Guid.CreateVersion7();

        var result = await Create(kit, fiadoId, FiadoPayload(clientId, 4000));

        Assert.True(result.IsApplied, result.Code);
        Assert.Equal(4000, (await kit.GetFiado(fiadoId)).Total);
        Assert.Empty(await kit.GetItems(fiadoId));
    }

    [Fact]
    public async Task Sin_items_ni_monto_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var result = await Create(kit, Guid.CreateVersion7(), new { clientId, items = Array.Empty<object>() });

        Assert.Equal("fiado_empty", result.Code);
        Assert.Empty(kit.Db.Fiados);
    }

    // ---- cliente archivado (RF-85)

    [Fact]
    public async Task Un_fiado_a_un_cliente_archivado_se_acepta_y_el_cliente_sigue_archivado()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        Assert.True((await kit.Applier.ApplyAsync(Op("client.archive", clientId, baseVersion: 1), kit.Owner)).IsApplied);
        var fiadoId = Guid.CreateVersion7();

        var result = await Create(kit, fiadoId, FiadoPayload(clientId, 2500, Item()));

        Assert.True(result.IsApplied, result.Code);
        Assert.Equal(2500, (await kit.GetFiado(fiadoId)).Total);
        Assert.True((await kit.GetClient(clientId)).Archived);
    }

    [Fact]
    public async Task Un_fiado_a_un_cliente_inexistente_o_con_un_producto_inexistente_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var noClient = await Create(kit, Guid.CreateVersion7(), FiadoPayload(Guid.CreateVersion7(), 2500, Item()));
        var noProduct = await Create(kit, Guid.CreateVersion7(),
            FiadoPayload(clientId, 2500, Item(productId: Guid.CreateVersion7())));

        Assert.Equal("client_not_found", noClient.Code);
        Assert.Equal("product_not_found", noProduct.Code);
        Assert.Empty(kit.Db.Fiados);
    }

    [Fact]
    public async Task Un_producto_archivado_se_acepta_porque_otro_dispositivo_pudo_no_saberlo()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var productId = await kit.NewProductAsync();
        Assert.True((await kit.Applier.ApplyAsync(Op("product.archive", productId, baseVersion: 1), kit.Owner)).IsApplied);

        var result = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 2500, Item(productId: productId)));

        Assert.True(result.IsApplied, result.Code);
    }

    // ---- validación (RF-32, 33, 35, 36, 84)

    [Fact]
    public async Task Cantidad_precio_o_monto_en_cero_o_negativos_se_rechazan_con_su_codigo()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var zeroQuantity = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 100, Item(quantity: 0, subtotal: 100)));
        var zeroPrice = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 100, Item(unitPrice: 0, subtotal: 100)));
        var negativeTotal = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, -500));
        var zeroTotal = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 0));

        Assert.Equal("quantity_not_positive", zeroQuantity.Code);
        Assert.Equal("amount_not_positive", zeroPrice.Code);
        Assert.Equal("amount_not_positive", negativeTotal.Code);
        Assert.Equal("amount_not_positive", zeroTotal.Code);
        Assert.Empty(kit.Db.Fiados);
    }

    [Fact]
    public async Task Con_cantidades_enteras_una_fraccion_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres, quantityMode: QuantityMode.Integer);
        var clientId = await kit.NewClientAsync();

        var result = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 3750, Item(quantity: 1500)));

        Assert.Equal("quantity_not_whole", result.Code);
    }

    [Fact]
    public async Task Con_montos_enteros_un_precio_o_un_total_con_centavos_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres, AmountMode.Integer);
        var clientId = await kit.NewClientAsync();

        var price = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 2550, Item(unitPrice: 2550, subtotal: 2550)));
        var total = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 2550));

        Assert.Equal("amount_not_whole", price.Code);
        Assert.Equal("amount_not_whole", total.Code);
    }

    [Fact]
    public async Task Una_unidad_desconocida_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var result = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 2500, Item(unit: "metro")));

        Assert.Equal("item_unit_unknown", result.Code);
    }

    // ---- coherencia de subtotales y total

    [Fact]
    public async Task Un_subtotal_que_no_corresponde_a_cantidad_por_precio_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var result = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 9999, Item(subtotal: 9999)));

        Assert.Equal("subtotal_mismatch", result.Code);
        Assert.Empty(kit.Db.Fiados);
    }

    [Fact]
    public async Task Un_total_que_no_es_la_suma_de_los_subtotales_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var result = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 9999, Item()));

        Assert.Equal("total_mismatch", result.Code);
    }

    [Theory]
    [InlineData(250L)] // redondeo al centavo: 0.5 x L 5.00 = L 2.50
    [InlineData(300L)] // redondeo al lempira: un dispositivo que aún trabajaba con montos enteros
    public async Task Se_acepta_el_subtotal_de_cualquiera_de_los_dos_redondeos_por_si_el_modo_cambio_sin_conexion(long subtotal)
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = Guid.CreateVersion7();

        var result = await Create(kit, fiadoId,
            FiadoPayload(clientId, subtotal, Item(quantity: 500, unitPrice: 500, subtotal: subtotal)));

        Assert.True(result.IsApplied, result.Code);
        Assert.Equal(subtotal, (await kit.GetFiado(fiadoId)).Total);
    }

    // ---- topes (D-26)

    [Fact]
    public async Task Los_valores_en_el_tope_se_aceptan()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var max = LedgerLimits.MaxAmountMinorUnits;

        var price = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, max, Item(quantity: 1000, unitPrice: max)));
        var quantity = await Create(kit, Guid.CreateVersion7(),
            FiadoPayload(clientId, 1_000_000, Item(quantity: LedgerLimits.MaxQuantityMilli, unitPrice: 1, subtotal: 1_000_000)));
        var items = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 200 * 100,
            Enumerable.Range(0, LedgerLimits.MaxItemsPerFiado).Select(_ => Item(unitPrice: 100)).ToArray()));
        var description = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 2500,
            Item(description: new string('a', LedgerLimits.MaxDescriptionLength))));

        Assert.True(price.IsApplied, price.Code);
        Assert.True(items.IsApplied, items.Code);
        Assert.True(description.IsApplied, description.Code);
        Assert.True(quantity.IsApplied, quantity.Code);
    }

    [Fact]
    public async Task Pasar_un_tope_se_rechaza_con_su_codigo_sin_guardar_nada()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var over = LedgerLimits.MaxAmountMinorUnits + 1;

        var price = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, over, Item(unitPrice: over, subtotal: over)));
        var total = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, over));
        var quantity = await Create(kit, Guid.CreateVersion7(),
            FiadoPayload(clientId, 100, Item(quantity: LedgerLimits.MaxQuantityMilli + 1, unitPrice: 1, subtotal: 100)));
        var items = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 201 * 100,
            Enumerable.Range(0, LedgerLimits.MaxItemsPerFiado + 1).Select(_ => Item(unitPrice: 100)).ToArray()));
        var description = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 2500,
            Item(description: new string('a', LedgerLimits.MaxDescriptionLength + 1))));
        var huge = await Create(kit, Guid.CreateVersion7(),
            FiadoPayload(clientId, long.MaxValue, Item(quantity: long.MaxValue, unitPrice: long.MaxValue, subtotal: long.MaxValue)));

        Assert.Equal("amount_too_large", price.Code);
        Assert.Equal("amount_too_large", total.Code);
        Assert.Equal("quantity_too_large", quantity.Code);
        Assert.Equal("too_many_items", items.Code);
        Assert.Equal("description_too_long", description.Code);
        Assert.NotNull(huge.Code);
        Assert.Empty(kit.Db.Fiados);
    }

    // ---- identificadores y forma

    [Fact]
    public async Task Un_id_de_fiado_o_de_item_repetido_se_rechaza_sin_romper()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = Guid.CreateVersion7();
        var itemId = Guid.CreateVersion7();
        Assert.True((await Create(kit, fiadoId, FiadoPayload(clientId, 2500, Item(id: itemId)))).IsApplied);

        var sameFiado = await Create(kit, fiadoId, FiadoPayload(clientId, 2500, Item()));
        var sameItemElsewhere = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 2500, Item(id: itemId)));
        var twin = Item(unitPrice: 100);
        var sameItemTwice = await Create(kit, Guid.CreateVersion7(), FiadoPayload(clientId, 200, twin, twin));

        Assert.Equal("entity_already_exists", sameFiado.Code);
        Assert.Equal("entity_already_exists", sameItemElsewhere.Code);
        Assert.Equal("duplicate_item_id", sameItemTwice.Code);
        Assert.Single(kit.Db.Fiados);
    }

    [Fact]
    public async Task Un_payload_sin_cliente_o_con_items_que_no_son_una_lista_es_invalido()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();

        var noClient = await Create(kit, Guid.CreateVersion7(), new { total = 2500, items = Array.Empty<object>() });
        var badItems = await Create(kit, Guid.CreateVersion7(), new { clientId, total = 2500, items = "uno" });
        var badItem = await Create(kit, Guid.CreateVersion7(), new { clientId, total = 2500, items = new[] { 5 } });
        var noTotal = await Create(kit, Guid.CreateVersion7(), new { clientId, items = new[] { Item() } });

        Assert.Equal("invalid_payload", noClient.Code);
        Assert.Equal("invalid_payload", badItems.Code);
        Assert.Equal("invalid_payload", badItem.Code);
        Assert.Equal("invalid_payload", noTotal.Code);
    }
}
