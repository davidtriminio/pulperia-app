using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Team;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T081: un empleado removido envía un último lote, sin límite de tiempo, y después pierde el acceso (RF-11, RF-12).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class RemovedEmployeeTests(PostgresFixture postgres)
{
    private sealed record World(SyncKit Kit, SyncAccount Beto, Guid Client);

    /// <summary>Beto es empleado de Ana, ya conoce a un cliente, y la dueña lo quita por la API.</summary>
    private async Task<World> SetupRemoved()
    {
        var kit = await StartAsync(postgres);
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var client = Guid.CreateVersion7();
        await kit.PushOkAsync(kit.Owner, SyncOp("client.create", client, ClientPayload("Ana")));
        await RemoveByOwner(kit, beto);
        return new World(kit, beto, client);
    }

    private static async Task RemoveByOwner(SyncKit kit, SyncAccount who)
    {
        var removal = await kit.Host.DeleteAsync($"/api/business/team/{who.UserId}", kit.Owner.Token, kit.BusinessId);
        Assert.Equal(HttpStatusCode.NoContent, removal.StatusCode);
    }

    private static object[] OfflineWork(Guid client) =>
    [
        SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, 300)),
        SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, 800)),
    ];

    [Fact]
    public async Task Su_primer_envio_tras_la_baja_se_acepta_y_el_siguiente_se_rechaza()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;

        var last = await w.Kit.PushAsync(w.Beto, OfflineWork(w.Client));
        var next = await w.Kit.PushAsync(w.Beto, OfflineWork(w.Client));

        Assert.Equal(HttpStatusCode.OK, last.StatusCode);
        Assert.Equal(["applied", "applied"],
            (await ApiTestHost.JsonOf(last)).GetProperty("results").EnumerateArray().Select(Status).ToArray());
        Assert.Equal(HttpStatusCode.Forbidden, next.StatusCode);
        Assert.Equal("forbidden", (await ApiTestHost.JsonOf(next)).GetProperty("code").GetString());
        Assert.Equal(1, await w.Kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
        Assert.True((await w.Kit.Host.Db.Memberships.AsNoTracking().SingleAsync(m => m.UserId == w.Beto.UserId && m.BusinessId == w.Kit.BusinessId)).FinalSyncUsed);
    }

    [Fact]
    public async Task No_hay_limite_de_tiempo_desde_la_baja()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;
        await w.Kit.Host.Db.Memberships
            .Where(m => m.UserId == w.Beto.UserId && m.BusinessId == w.Kit.BusinessId)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.RemovedAt, DateTime.UtcNow.AddYears(-3)));

        var results = await w.Kit.PushOkAsync(w.Beto, OfflineWork(w.Client));

        Assert.All(results, r => Assert.Equal("applied", Status(r)));
    }

    [Fact]
    public async Task El_ultimo_lote_se_procesa_con_las_reglas_normales_y_conserva_al_autor()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;
        var fiado = Guid.CreateVersion7();
        await w.Kit.PushOkAsync(w.Kit.Owner, SyncOp("fiado.create", fiado, FiadoPayload(w.Client, 500)));

        var results = await w.Kit.PushOkAsync(
            w.Beto,
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(w.Client, 300)),
            SyncOp("fiado.annul", fiado),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(Guid.CreateVersion7(), 100)));

        Assert.Equal(["applied", "rejected", "rejected"], results.Select(Status).ToArray());
        Assert.Equal(["forbidden", "client_not_found"], results.Skip(1).Select(Code).ToArray());
        Assert.Equal(w.Beto.UserId, (await w.Kit.Host.Db.Payments.IgnoreQueryFilters().SingleAsync()).CreatedBy);
    }

    [Fact]
    public async Task El_removido_no_puede_leer_los_datos_ni_antes_ni_despues_de_su_ultimo_lote()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;

        var before = await w.Kit.PullAsync(w.Beto);
        await w.Kit.PushOkAsync(w.Beto, OfflineWork(w.Client));
        var after = await w.Kit.PullAsync(w.Beto);

        Assert.Equal([HttpStatusCode.Forbidden, HttpStatusCode.Forbidden], [before.StatusCode, after.StatusCode]);
    }

    [Fact]
    public async Task Dos_ultimos_lotes_simultaneos_solo_dejan_pasar_uno()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;

        var both = await Task.WhenAll(w.Kit.PushAsync(w.Beto, OfflineWork(w.Client)), w.Kit.PushAsync(w.Beto, OfflineWork(w.Client)));

        Assert.Equal(
            [HttpStatusCode.OK, HttpStatusCode.Forbidden],
            both.Select(r => r.StatusCode).Order().ToArray());
        Assert.Equal(1, await w.Kit.Host.Db.Payments.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task Un_ultimo_lote_que_falla_no_gasta_la_oportunidad()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;
        await w.Kit.Host.Db.Database.ExecuteSqlRawAsync(
            """
            CREATE FUNCTION fail_change() RETURNS trigger AS $$
            BEGIN RAISE EXCEPTION 'falla simulada'; END $$ LANGUAGE plpgsql;
            CREATE TRIGGER fail_change BEFORE INSERT ON change_log
            FOR EACH ROW EXECUTE FUNCTION fail_change();
            """);

        var broken = await w.Kit.PushAsync(w.Beto, OfflineWork(w.Client));
        await w.Kit.Host.Db.Database.ExecuteSqlRawAsync("DROP TRIGGER fail_change ON change_log");
        var retry = await w.Kit.PushOkAsync(w.Beto, OfflineWork(w.Client));

        Assert.Equal(HttpStatusCode.InternalServerError, broken.StatusCode);
        Assert.All(retry, r => Assert.Equal("applied", Status(r)));
    }

    [Fact]
    public async Task Quien_vuelve_a_entrar_y_es_quitado_otra_vez_tiene_un_nuevo_ultimo_lote()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;
        await w.Kit.PushOkAsync(w.Beto, OfflineWork(w.Client));
        Assert.Equal(HttpStatusCode.Forbidden, (await w.Kit.PushAsync(w.Beto, OfflineWork(w.Client))).StatusCode);

        // La dueña lo invita de nuevo, él acepta, trabaja y lo quitan otra vez.
        var invite = await w.Kit.Host.PostAsync("/api/business/invitations", new { email = "beto@correo.com" }, w.Kit.Owner.Token, w.Kit.BusinessId);
        Assert.Equal(HttpStatusCode.Created, invite.StatusCode);
        var invitationId = (await ApiTestHost.JsonOf(invite)).GetProperty("id").GetGuid();
        var accept = await w.Kit.Host.PostAsync($"/api/invitations/{invitationId}/accept", null, w.Beto.Token);
        Assert.True(accept.IsSuccessStatusCode, await accept.Content.ReadAsStringAsync());
        await w.Kit.PushOkAsync(w.Beto, OfflineWork(w.Client));
        await RemoveByOwner(w.Kit, w.Beto);

        var results = await w.Kit.PushOkAsync(w.Beto, OfflineWork(w.Client));

        Assert.All(results, r => Assert.Equal("applied", Status(r)));
        Assert.Equal(HttpStatusCode.Forbidden, (await w.Kit.PushAsync(w.Beto, OfflineWork(w.Client))).StatusCode);
    }

    [Fact]
    public async Task Ser_quitado_de_un_negocio_no_afecta_el_envio_a_los_demas()
    {
        var w = await SetupRemoved();
        await using var _ = w.Kit;
        var own = Guid.CreateVersion7();

        var response = await w.Kit.Host.PostAsync(
            "/api/sync/push",
            new { operations = new[] { SyncOp("client.create", own, ClientPayload("De Beto")) } },
            w.Beto.Token, w.Beto.BusinessId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(MembershipStatus.Removed,
            (await w.Kit.Host.Db.Memberships.AsNoTracking().SingleAsync(m => m.UserId == w.Beto.UserId && m.BusinessId == w.Kit.BusinessId)).Status);
    }
}
