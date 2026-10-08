using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T056: operaciones de cliente (crear, editar con versión, archivar, restaurar) contra PostgreSQL real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ClientOperationTests(PostgresFixture postgres)
{
    private async Task<(OperationKit Kit, Guid ClientId)> WithClient(string name = "Ana López")
    {
        var kit = await CreateAsync(postgres);
        var id = Guid.CreateVersion7();
        var result = await kit.Applier.ApplyAsync(Op("client.create", id, ClientPayload(name)), kit.Owner);
        Assert.True(result.IsApplied, result.Code);
        return (kit, id);
    }

    // ---- crear

    [Fact]
    public async Task Crear_guarda_el_cliente_con_su_autor_version_uno_y_la_fecha_de_la_operacion()
    {
        var (kit, id) = await WithClient("  Ana López  ");
        await using var _ = kit;

        var client = await kit.GetClient(id);
        Assert.Equal("Ana López", client.Name);
        Assert.Equal(kit.BusinessId, client.BusinessId);
        Assert.Equal(kit.OwnerId, client.CreatedBy);
        Assert.Equal(1, client.Version);
        Assert.False(client.Archived);
        Assert.Equal(At.UtcDateTime, client.CreatedAt);
        Assert.Equal(At.UtcDateTime, client.UpdatedAt);
        Assert.Equal("char-01", client.CharacterId);
    }

    [Fact]
    public async Task Crear_guarda_telefono_direccion_y_nota_y_los_vacios_quedan_ausentes()
    {
        await using var kit = await CreateAsync(postgres);
        var withData = Guid.CreateVersion7();
        var blanks = Guid.CreateVersion7();

        Assert.True((await kit.Applier.ApplyAsync(
            Op("client.create", withData, ClientPayload(phone: "98765432", address: "Barrio Abajo", note: "Paga los viernes")),
            kit.Employee)).IsApplied);
        Assert.True((await kit.Applier.ApplyAsync(
            Op("client.create", blanks, ClientPayload(phone: "", address: "", note: "")), kit.Employee)).IsApplied);

        var full = await kit.GetClient(withData);
        Assert.Equal(("98765432", "Barrio Abajo", "Paga los viernes"), (full.Phone, full.Address, full.Note));
        var empty = await kit.GetClient(blanks);
        Assert.Equal((null, null, null), (empty.Phone, empty.Address, empty.Note));
    }

    [Theory]
    [InlineData("", "name_required")]
    [InlineData("   ", "name_required")]
    public async Task Crear_sin_nombre_se_rechaza_con_su_codigo(string name, string code)
    {
        await using var kit = await CreateAsync(postgres);
        var id = Guid.CreateVersion7();

        var result = await kit.Applier.ApplyAsync(Op("client.create", id, ClientPayload(name)), kit.Owner);

        Assert.False(result.IsApplied);
        Assert.Equal(code, result.Code);
        Assert.Empty(kit.Db.Clients);
    }

    [Fact]
    public async Task Crear_sin_avatar_completo_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(
            Op("client.create", Guid.CreateVersion7(), new { name = "Ana", characterId = "char-01" }), kit.Owner);

        Assert.False(result.IsApplied);
        Assert.Contains("avatar_skin_required", result.Details);
        Assert.Contains("avatar_background_required", result.Details);
    }

    [Fact]
    public async Task Crear_con_telefono_o_nota_invalidos_reporta_todos_los_problemas()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(
            Op("client.create", Guid.CreateVersion7(), ClientPayload(phone: "123", note: new string('x', 301))),
            kit.Owner);

        Assert.False(result.IsApplied);
        Assert.Contains("phone_invalid_format", result.Details);
        Assert.Contains("note_too_long", result.Details);
    }

    [Fact]
    public async Task Crear_con_un_id_que_ya_existe_se_rechaza_sin_tocar_el_cliente()
    {
        var (kit, id) = await WithClient("Ana");
        await using var _ = kit;

        var result = await kit.Applier.ApplyAsync(Op("client.create", id, ClientPayload("Otra")), kit.Owner);

        Assert.False(result.IsApplied);
        Assert.Equal("entity_already_exists", result.Code);
        Assert.Equal("Ana", (await kit.GetClient(id)).Name);
    }

    [Fact]
    public async Task Un_payload_que_no_es_un_objeto_se_rechaza_como_invalido()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(Op("client.create", Guid.CreateVersion7(), "texto"), kit.Owner);

        Assert.Equal("invalid_payload", result.Code);
    }

    [Fact]
    public async Task Un_tipo_de_operacion_desconocido_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(Op("client.delete", Guid.CreateVersion7()), kit.Owner);

        Assert.Equal("unknown_operation", result.Code);
    }

    // ---- editar con versión

    [Fact]
    public async Task Editar_con_la_version_actual_cambia_los_datos_y_sube_la_version()
    {
        var (kit, id) = await WithClient();
        await using var _ = kit;
        var later = At.AddHours(2);

        var result = await kit.Applier.ApplyAsync(
            Op("client.update", id, ClientPayload("Ana María", phone: "98765432"), baseVersion: 1, at: later),
            kit.Employee);

        Assert.True(result.IsApplied, result.Code);
        var client = await kit.GetClient(id);
        Assert.Equal("Ana María", client.Name);
        Assert.Equal("98765432", client.Phone);
        Assert.Equal(2, client.Version);
        Assert.Equal(later.UtcDateTime, client.UpdatedAt);
        Assert.Equal(At.UtcDateTime, client.CreatedAt);
        Assert.Equal(kit.OwnerId, client.CreatedBy);
    }

    [Fact]
    public async Task Editar_con_version_desfasada_se_rechaza_con_conflicto_y_no_sobrescribe()
    {
        var (kit, id) = await WithClient("Ana");
        await using var _ = kit;
        Assert.True((await kit.Applier.ApplyAsync(
            Op("client.update", id, ClientPayload("Ana del servidor"), baseVersion: 1), kit.Owner)).IsApplied);

        var stale = await kit.Applier.ApplyAsync(
            Op("client.update", id, ClientPayload("Ana del móvil"), baseVersion: 1), kit.Employee);

        Assert.False(stale.IsApplied);
        Assert.Equal("version_conflict", stale.Code);
        var client = await kit.GetClient(id);
        Assert.Equal("Ana del servidor", client.Name);
        Assert.Equal(2, client.Version);
    }

    [Fact]
    public async Task Ediciones_seguidas_sin_sincronizar_encadenan_sus_versiones_base()
    {
        var (kit, id) = await WithClient("Ana");
        await using var _ = kit;

        Assert.True((await kit.Applier.ApplyAsync(Op("client.update", id, ClientPayload("Ana 2"), baseVersion: 1), kit.Owner)).IsApplied);
        Assert.True((await kit.Applier.ApplyAsync(Op("client.update", id, ClientPayload("Ana 3"), baseVersion: 2), kit.Owner)).IsApplied);

        var client = await kit.GetClient(id);
        Assert.Equal(("Ana 3", 3), (client.Name, client.Version));
    }

    [Fact]
    public async Task Editar_sin_version_base_se_rechaza()
    {
        var (kit, id) = await WithClient();
        await using var _ = kit;

        var result = await kit.Applier.ApplyAsync(Op("client.update", id, ClientPayload("Otro")), kit.Owner);

        Assert.Equal("base_version_required", result.Code);
    }

    [Fact]
    public async Task Editar_un_cliente_inexistente_o_con_datos_invalidos_se_rechaza()
    {
        var (kit, id) = await WithClient("Ana");
        await using var _ = kit;

        var missing = await kit.Applier.ApplyAsync(
            Op("client.update", Guid.CreateVersion7(), ClientPayload("X"), baseVersion: 1), kit.Owner);
        var invalid = await kit.Applier.ApplyAsync(Op("client.update", id, ClientPayload(""), baseVersion: 1), kit.Owner);

        Assert.Equal("client_not_found", missing.Code);
        Assert.Equal("name_required", invalid.Code);
        var client = await kit.GetClient(id);
        Assert.Equal(("Ana", 1), (client.Name, client.Version));
    }

    [Fact]
    public async Task Editar_no_toca_si_el_cliente_esta_archivado()
    {
        var (kit, id) = await WithClient();
        await using var _ = kit;
        Assert.True((await kit.Applier.ApplyAsync(Op("client.archive", id, baseVersion: 1), kit.Owner)).IsApplied);

        Assert.True((await kit.Applier.ApplyAsync(
            Op("client.update", id, ClientPayload("Ana nueva"), baseVersion: 2), kit.Owner)).IsApplied);

        Assert.True((await kit.GetClient(id)).Archived);
    }

    // ---- archivar y restaurar

    [Fact]
    public async Task Archivar_y_restaurar_cambian_el_estado_y_suben_la_version()
    {
        var (kit, id) = await WithClient();
        await using var _ = kit;

        Assert.True((await kit.Applier.ApplyAsync(Op("client.archive", id, baseVersion: 1), kit.Owner)).IsApplied);
        var archived = await kit.GetClient(id);
        Assert.Equal((true, 2), (archived.Archived, archived.Version));

        Assert.True((await kit.Applier.ApplyAsync(Op("client.restore", id, baseVersion: 2), kit.Owner)).IsApplied);
        var restored = await kit.GetClient(id);
        Assert.Equal((false, 3), (restored.Archived, restored.Version));
    }

    [Fact]
    public async Task Archivar_uno_ya_archivado_o_restaurar_uno_activo_se_acepta_sin_cambiar_nada()
    {
        var (kit, id) = await WithClient();
        await using var _ = kit;

        Assert.True((await kit.Applier.ApplyAsync(Op("client.restore", id, baseVersion: 1), kit.Owner)).IsApplied);
        Assert.Equal(1, (await kit.GetClient(id)).Version);

        Assert.True((await kit.Applier.ApplyAsync(Op("client.archive", id, baseVersion: 1), kit.Owner)).IsApplied);
        Assert.True((await kit.Applier.ApplyAsync(Op("client.archive", id, baseVersion: 1), kit.Owner)).IsApplied);
        var client = await kit.GetClient(id);
        Assert.Equal((true, 2), (client.Archived, client.Version));
    }

    [Fact]
    public async Task Archivar_un_cliente_inexistente_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Applier.ApplyAsync(Op("client.archive", Guid.CreateVersion7(), baseVersion: 1), kit.Owner);

        Assert.Equal("client_not_found", result.Code);
    }
}
