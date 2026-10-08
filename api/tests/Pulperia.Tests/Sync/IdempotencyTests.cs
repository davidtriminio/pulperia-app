using Microsoft.EntityFrameworkCore;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T075: reenviar un lote no duplica nada, por <c>op_id</c> (RF-53).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class IdempotencyTests(PostgresFixture postgres)
{
    private static readonly Guid Unknown = Guid.CreateVersion7();

    [Fact]
    public async Task Reenviar_el_mismo_lote_tres_veces_deja_un_solo_fiado_abono_y_anulacion()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        var fiado = Guid.CreateVersion7();
        var payment = Guid.CreateVersion7();
        var paymentToAnnul = Guid.CreateVersion7();
        object[] batch =
        [
            SyncOp("client.create", client, ClientPayload("Ana")),
            SyncOp("fiado.create", fiado, FiadoPayload(client, 3000)),
            SyncOp("payment.create", payment, PaymentPayload(client, 500)),
            SyncOp("payment.create", paymentToAnnul, PaymentPayload(client, 700)),
            SyncOp("payment.annul", paymentToAnnul),
        ];

        var first = await kit.PushOkAsync(kit.Owner, batch);
        var second = await kit.PushOkAsync(kit.Owner, batch);
        var third = await kit.PushOkAsync(kit.Owner, batch);

        Assert.All(first, r => Assert.Equal("applied", Status(r)));
        Assert.All(second, r => Assert.Equal("duplicate", Status(r)));
        Assert.All(third, r => Assert.Equal("duplicate", Status(r)));
        Assert.Equal(first.Select(r => r.GetProperty("opId").GetGuid()), third.Select(r => r.GetProperty("opId").GetGuid()));
        Assert.Equal(1, await kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync());
        Assert.Equal(1, await kit.Host.Db.Fiados.IgnoreQueryFilters().CountAsync());
        Assert.Equal(2, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
        Assert.Single(await kit.Host.Db.Payments.IgnoreQueryFilters().Where(p => p.AnnulledAt != null).ToListAsync());
        // Cinco cambios (la anulación incluida) y ningún seq extra por los reenvíos.
        Assert.Equal(5, await kit.Host.Db.ChangeLog.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Una_operacion_repetida_dentro_del_mismo_lote_se_aplica_una_vez()
    {
        await using var kit = await StartAsync(postgres);
        var op = SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ana"));

        var results = await kit.PushOkAsync(kit.Owner, op, op);

        Assert.Equal(["applied", "duplicate"], results.Select(Status).ToArray());
        Assert.Equal(1, await kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Reenviar_una_operacion_rechazada_devuelve_el_mismo_rechazo_sin_volver_a_evaluarla()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        var payment = Guid.CreateVersion7();
        var op = SyncOp("payment.create", payment, PaymentPayload(client, 500));

        var first = (await kit.PushOkAsync(kit.Owner, op))[0];
        // El cliente aparece después; la operación ya fue rechazada y su resultado se conserva.
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        var again = (await kit.PushOkAsync(kit.Owner, op))[0];

        Assert.Equal(("rejected", "client_not_found"), (Status(first), Code(first)));
        Assert.Equal(("rejected", "client_not_found"), (Status(again), Code(again)));
        Assert.Equal(0, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Un_rechazo_con_varios_codigos_se_repite_con_todos_ellos()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        var op = SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, 5, Item(quantity: 2_000_000_000, unitPrice: 10_000_000_000, subtotal: 5)));

        var first = (await kit.PushOkAsync(kit.Owner, op))[0];
        var again = (await kit.PushOkAsync(kit.Owner, op))[0];

        string[] Codes(System.Text.Json.JsonElement r) => r.GetProperty("codes").EnumerateArray().Select(c => c.GetString()!).ToArray();
        Assert.Equal("rejected", Status(first));
        Assert.True(Codes(first).Length >= 2, string.Join(",", Codes(first)));
        Assert.Equal(Codes(first), Codes(again));
    }

    [Fact]
    public async Task Cada_operacion_procesada_queda_en_processed_ops_con_su_resultado()
    {
        await using var kit = await StartAsync(postgres);
        Guid applied = Guid.CreateVersion7(), rejected = Guid.CreateVersion7();

        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ana"), opId: applied),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(Unknown, 100), opId: rejected));

        var rows = await kit.Host.Db.ProcessedOps.IgnoreQueryFilters().ToDictionaryAsync(o => o.OpId);
        Assert.Equal("applied", rows[applied].Result);
        Assert.Equal("client_not_found", rows[rejected].Result);
        Assert.All(rows.Values, r => Assert.Equal(kit.BusinessId, r.BusinessId));
    }

    [Fact]
    public async Task Un_op_id_ya_usado_en_otro_negocio_se_rechaza_sin_revelar_nada_y_sin_romper_el_lote()
    {
        await using var kit = await StartAsync(postgres);
        var stranger = await RegisterAsync(kit.Host, "otra@correo.com");
        var shared = Guid.CreateVersion7();
        await kit.Host.PostAsync(
            "/api/sync/push",
            new { operations = new[] { SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("De ella"), opId: shared) } },
            stranger.Token, stranger.BusinessId);

        var results = await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Mío"), opId: shared),
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Otro mío")));

        Assert.Equal(("rejected", "op_id_in_use"), (Status(results[0]), Code(results[0])));
        Assert.Equal("applied", Status(results[1]));
        Assert.Equal(
            ["Otro mío"],
            await kit.Host.Db.Clients.IgnoreQueryFilters().Where(c => c.BusinessId == kit.BusinessId).Select(c => c.Name).ToListAsync());
    }

    [Fact]
    public async Task Dos_envios_simultaneos_del_mismo_lote_aplican_cada_operacion_una_sola_vez()
    {
        await using var kit = await StartAsync(postgres);
        var client = Guid.CreateVersion7();
        object[] batch =
        [
            SyncOp("client.create", client, ClientPayload("Ana")),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, 1000)),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, 300)),
        ];

        var both = await Task.WhenAll(kit.PushOkAsync(kit.Owner, batch), kit.PushOkAsync(kit.Owner, batch));

        for (var i = 0; i < batch.Length; i++)
        {
            Assert.Equal(["applied", "duplicate"], both.Select(r => Status(r[i])).Order().ToArray());
        }
        Assert.Equal(1, await kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync());
        Assert.Equal(1, await kit.Host.Db.Fiados.IgnoreQueryFilters().CountAsync());
        Assert.Equal(1, await kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Un_corte_a_mitad_de_lote_no_guarda_nada_y_el_reenvio_lo_aplica_completo()
    {
        await using var kit = await StartAsync(postgres);
        // La base falla al escribir el segundo cambio, con el primero ya guardado dentro del lote.
        await kit.Host.Db.Database.ExecuteSqlRawAsync(
            """
            CREATE FUNCTION fail_second_change() RETURNS trigger AS $$
            BEGIN IF NEW.seq = 2 THEN RAISE EXCEPTION 'falla simulada'; END IF; RETURN NEW; END $$ LANGUAGE plpgsql;
            CREATE TRIGGER fail_second_change BEFORE INSERT ON change_log
            FOR EACH ROW EXECUTE FUNCTION fail_second_change();
            """);
        object[] batch =
        [
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Ana")),
            SyncOp("client.create", Guid.CreateVersion7(), ClientPayload("Beto")),
        ];

        var cut = await kit.PushAsync(kit.Owner, batch);

        Assert.Equal(System.Net.HttpStatusCode.InternalServerError, cut.StatusCode);
        Assert.Equal(0, await kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync());
        Assert.Equal(0, await kit.Host.Db.ProcessedOps.IgnoreQueryFilters().CountAsync());
        Assert.Equal(0, await kit.Host.Db.ChangeLog.IgnoreQueryFilters().CountAsync());

        await kit.Host.Db.Database.ExecuteSqlRawAsync("DROP TRIGGER fail_second_change ON change_log");
        var retry = await kit.PushOkAsync(kit.Owner, batch);

        Assert.All(retry, r => Assert.Equal("applied", Status(r)));
        Assert.Equal(2, await kit.Host.Db.Clients.IgnoreQueryFilters().CountAsync());
    }
}
