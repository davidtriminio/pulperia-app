using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T057: operaciones de producto (crear, editar, archivar) contra PostgreSQL real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ProductOperationTests(PostgresFixture postgres)
{
    private static object ProductPayload(string name = "Arroz", long price = 2500, string? unit = "pound") =>
        new { name, price, unit };

    private async Task<(OperationKit Kit, Guid ProductId)> WithProduct(
        AmountMode amountMode = AmountMode.TwoDecimals)
    {
        var kit = await CreateAsync(postgres, amountMode);
        var id = Guid.CreateVersion7();
        var result = await kit.Applier.ApplyAsync(Op("product.create", id, ProductPayload()), kit.Employee);
        Assert.True(result.IsApplied, result.Code);
        return (kit, id);
    }

    // ---- crear

    [Fact]
    public async Task Crear_guarda_el_producto_con_su_precio_unidad_autor_y_version_uno()
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;

        var product = await kit.GetProduct(id);
        Assert.Equal("Arroz", product.Name);
        Assert.Equal(2500, product.Price);
        Assert.Equal(SaleUnit.Pound, product.Unit);
        Assert.Equal(kit.BusinessId, product.BusinessId);
        Assert.Equal(kit.EmployeeId, product.CreatedBy);
        Assert.Equal((1, false), (product.Version, product.Archived));
        Assert.Equal(At.UtcDateTime, product.CreatedAt);
        Assert.Null(product.PreviousPrice);
        Assert.Null(product.PriceChangedAt);
    }

    [Fact]
    public async Task Crear_sin_unidad_usa_la_unidad_por_omision_y_recorta_el_nombre()
    {
        await using var kit = await CreateAsync(postgres);
        var id = Guid.CreateVersion7();

        Assert.True((await kit.Applier.ApplyAsync(
            Op("product.create", id, new { name = "  Jabón  ", price = 1000 }), kit.Owner)).IsApplied);

        var product = await kit.GetProduct(id);
        Assert.Equal(("Jabón", SaleUnit.Unit), (product.Name, product.Unit));
    }

    [Theory]
    [InlineData("", 2500, "pound", "product_name_required")]
    [InlineData("   ", 2500, "pound", "product_name_required")]
    [InlineData("Arroz", 0, "pound", "amount_not_positive")]
    [InlineData("Arroz", -5, "pound", "amount_not_positive")]
    [InlineData("Arroz", 2500, "metro", "product_unit_unknown")]
    public async Task Crear_con_datos_invalidos_se_rechaza_con_su_codigo(string name, long price, string unit, string code)
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(
            Op("product.create", Guid.CreateVersion7(), ProductPayload(name, price, unit)), kit.Owner);

        Assert.False(result.IsApplied);
        Assert.Equal(code, result.Code);
        Assert.Empty(kit.Db.Products);
    }

    [Fact]
    public async Task Con_montos_enteros_un_precio_con_centavos_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres, AmountMode.Integer);

        var result = await kit.Applier.ApplyAsync(
            Op("product.create", Guid.CreateVersion7(), ProductPayload(price: 2550)), kit.Owner);

        Assert.Equal("amount_not_whole", result.Code);
    }

    [Fact]
    public async Task Un_precio_que_no_es_numero_entero_es_un_payload_invalido()
    {
        await using var kit = await CreateAsync(postgres);

        var textual = await kit.Applier.ApplyAsync(
            Op("product.create", Guid.CreateVersion7(), new { name = "Arroz", price = "25.00" }), kit.Owner);
        var fractional = await kit.Applier.ApplyAsync(
            Op("product.create", Guid.CreateVersion7(), new { name = "Arroz", price = 25.5 }), kit.Owner);
        var missing = await kit.Applier.ApplyAsync(
            Op("product.create", Guid.CreateVersion7(), new { name = "Arroz" }), kit.Owner);

        Assert.Equal("invalid_payload", textual.Code);
        Assert.Equal("invalid_payload", fractional.Code);
        Assert.Equal("invalid_payload", missing.Code);
    }

    [Fact]
    public async Task Crear_con_un_id_que_ya_existe_se_rechaza()
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;

        var result = await kit.Applier.ApplyAsync(Op("product.create", id, ProductPayload("Frijol")), kit.Owner);

        Assert.Equal("entity_already_exists", result.Code);
        Assert.Equal("Arroz", (await kit.GetProduct(id)).Name);
    }

    // ---- editar

    [Fact]
    public async Task Editar_con_la_version_actual_cambia_nombre_precio_y_unidad()
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;

        var result = await kit.Applier.ApplyAsync(
            Op("product.update", id, ProductPayload("Arroz grano largo", 2800, "kilo"), baseVersion: 1), kit.Owner);

        Assert.True(result.IsApplied, result.Code);
        var product = await kit.GetProduct(id);
        Assert.Equal(("Arroz grano largo", 2800L, SaleUnit.Kilo, 2), (product.Name, product.Price, product.Unit, product.Version));
        Assert.Equal(kit.EmployeeId, product.CreatedBy);
    }

    [Fact]
    public async Task Editar_con_version_desfasada_se_rechaza_con_conflicto_y_no_sobrescribe()
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;
        Assert.True((await kit.Applier.ApplyAsync(
            Op("product.update", id, ProductPayload("Arroz", 3000), baseVersion: 1), kit.Owner)).IsApplied);

        var stale = await kit.Applier.ApplyAsync(
            Op("product.update", id, ProductPayload("Arroz", 9999), baseVersion: 1), kit.Employee);

        Assert.Equal("version_conflict", stale.Code);
        Assert.Equal(3000, (await kit.GetProduct(id)).Price);
    }

    [Fact]
    public async Task Editar_sin_version_base_inexistente_o_invalido_se_rechaza()
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;

        var noVersion = await kit.Applier.ApplyAsync(Op("product.update", id, ProductPayload()), kit.Owner);
        var missing = await kit.Applier.ApplyAsync(
            Op("product.update", Guid.CreateVersion7(), ProductPayload(), baseVersion: 1), kit.Owner);
        var invalid = await kit.Applier.ApplyAsync(
            Op("product.update", id, ProductPayload("", 100), baseVersion: 1), kit.Owner);

        Assert.Equal("base_version_required", noVersion.Code);
        Assert.Equal("product_not_found", missing.Code);
        Assert.Equal("product_name_required", invalid.Code);
        Assert.Equal(1, (await kit.GetProduct(id)).Version);
    }

    // ---- archivar

    [Fact]
    public async Task Archivar_marca_el_producto_conserva_nombre_y_precio_y_sube_la_version()
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;

        Assert.True((await kit.Applier.ApplyAsync(Op("product.archive", id, baseVersion: 1), kit.Owner)).IsApplied);

        var product = await kit.GetProduct(id);
        Assert.Equal((true, 2, "Arroz", 2500L), (product.Archived, product.Version, product.Name, product.Price));
    }

    [Fact]
    public async Task Archivar_uno_ya_archivado_se_acepta_sin_cambiar_nada()
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;
        await kit.Applier.ApplyAsync(Op("product.archive", id, baseVersion: 1), kit.Owner);

        var again = await kit.Applier.ApplyAsync(Op("product.archive", id, baseVersion: 1), kit.Owner);

        Assert.True(again.IsApplied);
        Assert.Equal(2, (await kit.GetProduct(id)).Version);
    }

    [Fact]
    public async Task Archivar_un_producto_inexistente_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(Op("product.archive", Guid.CreateVersion7()), kit.Owner);

        Assert.Equal("product_not_found", result.Code);
    }

    // ---- nunca se borra (RF-27)

    [Theory]
    [InlineData("product.delete")]
    [InlineData("product.remove")]
    public async Task No_existe_una_operacion_para_borrar_un_producto(string type)
    {
        var (kit, id) = await WithProduct();
        await using var _ = kit;

        var result = await kit.Applier.ApplyAsync(Op(type, id), kit.Owner);

        Assert.Equal("unknown_operation", result.Code);
        Assert.NotNull(await kit.GetProduct(id));
    }
}
