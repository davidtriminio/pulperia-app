using Pulperia.Application.Operations;
using Pulperia.Domain.Access;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T061: permisos de rol en cada operación, contra PostgreSQL real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class OperationPermissionTests(PostgresFixture postgres)
{
    private sealed record World(OperationKit Kit, Guid ClientId, Guid ProductId, Guid FiadoId, Guid PaymentId);

    private async Task<World> Setup()
    {
        var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var productId = await kit.NewProductAsync();
        var fiadoId = Guid.CreateVersion7();
        var paymentId = Guid.CreateVersion7();
        Assert.True((await kit.Applier.ApplyAsync(
            Op("fiado.create", fiadoId, FiadoPayload(clientId, 2500, Item())), kit.Owner)).IsApplied);
        Assert.True((await kit.Applier.ApplyAsync(
            Op("payment.create", paymentId, PaymentPayload(clientId, 500)), kit.Owner)).IsApplied);
        return new World(kit, clientId, productId, fiadoId, paymentId);
    }

    // ---- lo que un empleado no puede (RF-13, RF-21, RF-45, RF-48)

    [Fact]
    public async Task Un_empleado_que_intenta_anular_un_fiado_o_un_abono_recibe_rechazo_y_nada_cambia()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var fiado = await w.Kit.Applier.ApplyAsync(Op("fiado.annul", w.FiadoId), w.Kit.Employee);
        var payment = await w.Kit.Applier.ApplyAsync(Op("payment.annul", w.PaymentId), w.Kit.Employee);

        Assert.Equal("forbidden", fiado.Code);
        Assert.Equal("forbidden", payment.Code);
        Assert.Null((await w.Kit.GetFiado(w.FiadoId)).AnnulledAt);
        Assert.Null((await w.Kit.GetPayment(w.PaymentId)).AnnulledAt);
    }

    [Fact]
    public async Task Un_empleado_que_intenta_archivar_o_restaurar_un_cliente_recibe_rechazo_y_nada_cambia()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        Assert.True((await w.Kit.Applier.ApplyAsync(Op("client.archive", w.ClientId, baseVersion: 1), w.Kit.Owner)).IsApplied);

        var restore = await w.Kit.Applier.ApplyAsync(Op("client.restore", w.ClientId, baseVersion: 2), w.Kit.Employee);
        Assert.Equal("forbidden", restore.Code);
        Assert.True((await w.Kit.GetClient(w.ClientId)).Archived);

        Assert.True((await w.Kit.Applier.ApplyAsync(Op("client.restore", w.ClientId, baseVersion: 2), w.Kit.Owner)).IsApplied);
        var archive = await w.Kit.Applier.ApplyAsync(Op("client.archive", w.ClientId, baseVersion: 3), w.Kit.Employee);
        Assert.Equal("forbidden", archive.Code);
        Assert.False((await w.Kit.GetClient(w.ClientId)).Archived);
    }

    [Fact]
    public async Task El_permiso_se_comprueba_antes_que_la_existencia_y_que_el_contenido()
    {
        await using var kit = await CreateAsync(postgres);

        var missing = await kit.Applier.ApplyAsync(Op("fiado.annul", Guid.CreateVersion7()), kit.Employee);
        var missingClient = await kit.Applier.ApplyAsync(Op("client.archive", Guid.CreateVersion7(), baseVersion: 1), kit.Employee);

        Assert.Equal("forbidden", missing.Code);
        Assert.Equal("forbidden", missingClient.Code);
    }

    // ---- lo que un empleado sí puede

    [Fact]
    public async Task Un_empleado_puede_crear_y_editar_clientes_y_productos_y_registrar_fiados_y_abonos()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var employee = w.Kit.Employee;

        var results = new[]
        {
            await w.Kit.Applier.ApplyAsync(Op("client.create", Guid.CreateVersion7(), ClientPayload("Beto")), employee),
            await w.Kit.Applier.ApplyAsync(Op("client.update", w.ClientId, ClientPayload("Ana M."), baseVersion: 1), employee),
            await w.Kit.Applier.ApplyAsync(Op("product.create", Guid.CreateVersion7(), new { name = "Sal", price = 500 }), employee),
            await w.Kit.Applier.ApplyAsync(
                Op("product.update", w.ProductId, new { name = "Arroz", price = 2600, unit = "pound" }, baseVersion: 1), employee),
            await w.Kit.Applier.ApplyAsync(Op("product.archive", w.ProductId, baseVersion: 2), employee),
            await w.Kit.Applier.ApplyAsync(
                Op("fiado.create", Guid.CreateVersion7(), FiadoPayload(w.ClientId, 2500, Item())), employee),
            await w.Kit.Applier.ApplyAsync(
                Op("payment.create", Guid.CreateVersion7(), PaymentPayload(w.ClientId, 500)), employee),
        };

        Assert.All(results, r => Assert.True(r.IsApplied, r.Code));
    }

    [Fact]
    public async Task El_dueno_puede_todas_las_operaciones_de_negocio()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var owner = w.Kit.Owner;

        var results = new[]
        {
            await w.Kit.Applier.ApplyAsync(Op("client.archive", w.ClientId, baseVersion: 1), owner),
            await w.Kit.Applier.ApplyAsync(Op("client.restore", w.ClientId, baseVersion: 2), owner),
            await w.Kit.Applier.ApplyAsync(Op("fiado.annul", w.FiadoId), owner),
            await w.Kit.Applier.ApplyAsync(Op("payment.annul", w.PaymentId), owner),
        };

        Assert.All(results, r => Assert.True(r.IsApplied, r.Code));
    }

    // ---- la tabla cubre todas las operaciones

    [Fact]
    public void Cada_tipo_de_operacion_tiene_un_permiso_y_coincide_con_la_matriz_de_roles()
    {
        var expected = new Dictionary<string, Permission>
        {
            ["client.create"] = Permission.CreateClient,
            ["client.update"] = Permission.EditClient,
            ["client.archive"] = Permission.ArchiveClient,
            ["client.restore"] = Permission.RestoreClient,
            ["product.create"] = Permission.ManageCatalog,
            ["product.update"] = Permission.ManageCatalog,
            ["product.archive"] = Permission.ManageCatalog,
            ["fiado.create"] = Permission.RegisterFiado,
            ["fiado.annul"] = Permission.AnnulMovement,
            ["payment.create"] = Permission.RegisterPayment,
            ["payment.annul"] = Permission.AnnulMovement,
        };

        Assert.Equivalent(expected.Keys, OperationCatalog.Types);
        foreach (var (type, permission) in expected)
        {
            Assert.Equal(permission, OperationCatalog.RequiredPermission(type));
        }
        Assert.Null(OperationCatalog.RequiredPermission("client.delete"));
    }
}
