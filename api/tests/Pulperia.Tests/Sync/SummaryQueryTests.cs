using System.Net;
using System.Text.Json;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>T085: el resumen del negocio desde el servidor, con los mismos vectores que el móvil (RF-63, RF-64, RF-65).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SummaryQueryTests(PostgresFixture postgres)
{
    private const string Vectors = "summary.json";

    public static TheoryData<string> Cases => SharedVectors.Names(Vectors);

    private static async Task<JsonElement> GetSummary(SyncKit kit, SyncAccount who, string query = "")
    {
        var response = await kit.Host.GetAsync("/api/summary" + query, who.Token, who.BusinessId == kit.BusinessId ? kit.BusinessId : who.BusinessId);
        var body = await ApiTestHost.JsonOf(response);
        Assert.True(response.IsSuccessStatusCode, $"{(int)response.StatusCode}: {body}");
        return body;
    }

    /// <summary>Deja en la base un cliente con exactamente ese saldo (positivo: un fiado; negativo: un abono).</summary>
    private static void Seed(SyncKit kit, SyncAccount owner, Guid id, string name, long balance, bool archived)
    {
        var now = OperationKit.At.UtcDateTime;
        kit.Host.Db.Clients.Add(new ClientEntity
        {
            Id = id, BusinessId = owner.BusinessId, Name = name, CharacterId = "char-01", SkinId = "skin-1",
            BackgroundId = "bg-01", Archived = archived, CreatedBy = owner.UserId, CreatedAt = now, UpdatedAt = now,
        });
        if (balance > 0)
        {
            kit.Host.Db.Fiados.Add(new FiadoEntity
            {
                Id = Guid.CreateVersion7(), BusinessId = owner.BusinessId, ClientId = id, Total = balance,
                OccurredAt = now, CreatedBy = owner.UserId,
            });
        }
        else if (balance < 0)
        {
            kit.Host.Db.Payments.Add(new PaymentEntity
            {
                Id = Guid.CreateVersion7(), BusinessId = owner.BusinessId, ClientId = id, Amount = -balance,
                OccurredAt = now, CreatedBy = owner.UserId,
            });
        }
    }

    [Theory]
    [MemberData(nameof(Cases))]
    public async Task El_resumen_del_servidor_cumple_los_vectores_compartidos(string name)
    {
        await using var kit = await StartAsync(postgres);
        var c = SharedVectors.Get(Vectors, name);
        foreach (var client in c.Input.GetProperty("clients").EnumerateArray())
        {
            Seed(kit, kit.Owner, Guid.Parse(client.GetProperty("id").GetString()!), client.GetProperty("name").GetString()!,
                client.GetProperty("balance").GetInt64(), client.GetProperty("archived").GetBoolean());
        }
        await kit.Host.Db.SaveChangesAsync();

        var summary = await GetSummary(kit, kit.Owner);

        Assert.Equal(c.Expected.GetProperty("debtTotal").GetInt64(), summary.GetProperty("debtTotal").GetInt64());
        Assert.Equal(c.Expected.GetProperty("creditTotal").GetInt64(), summary.GetProperty("creditTotal").GetInt64());
        Assert.Equal(
            c.Expected.GetProperty("topDebtorIds").EnumerateArray().Select(e => e.GetString()!).ToArray(),
            summary.GetProperty("debtors").EnumerateArray().Select(d => d.GetProperty("clientId").GetString()!).ToArray());
    }

    [Fact]
    public async Task Cada_deudor_trae_su_nombre_y_su_deuda_de_mayor_a_menor()
    {
        await using var kit = await StartAsync(postgres);
        Seed(kit, kit.Owner, Guid.CreateVersion7(), "Ana", 3000, false);
        Seed(kit, kit.Owner, Guid.CreateVersion7(), "Beto", 9000, false);
        Seed(kit, kit.Owner, Guid.CreateVersion7(), "Carla", -400, false);
        await kit.Host.Db.SaveChangesAsync();

        var summary = await GetSummary(kit, kit.Owner);

        var debtors = summary.GetProperty("debtors").EnumerateArray().ToArray();
        Assert.Equal(["Beto", "Ana"], debtors.Select(d => d.GetProperty("name").GetString()).ToArray());
        Assert.Equal([9000L, 3000L], debtors.Select(d => d.GetProperty("debt").GetInt64()).ToArray());
        Assert.Equal((12000L, 400L), (summary.GetProperty("debtTotal").GetInt64(), summary.GetProperty("creditTotal").GetInt64()));
    }

    [Fact]
    public async Task Los_movimientos_anulados_y_los_clientes_archivados_no_cuentan()
    {
        await using var kit = await StartAsync(postgres);
        Guid ana = Guid.CreateVersion7(), dora = Guid.CreateVersion7(), annulled = Guid.CreateVersion7();
        await kit.PushOkAsync(
            kit.Owner,
            SyncOp("client.create", ana, ClientPayload("Ana")),
            SyncOp("client.create", dora, ClientPayload("Dora")),
            SyncOp("fiado.create", annulled, FiadoPayload(ana, 5000)),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(ana, 700)),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(dora, 8000)),
            SyncOp("fiado.annul", annulled),
            SyncOp("client.archive", dora));

        var summary = await GetSummary(kit, kit.Owner);

        Assert.Equal(700L, summary.GetProperty("debtTotal").GetInt64());
        Assert.Equal([ana.ToString()], summary.GetProperty("debtors").EnumerateArray().Select(d => d.GetProperty("clientId").GetString()).ToArray());
    }

    [Fact]
    public async Task El_resumen_coincide_con_la_suma_de_los_saldos_de_la_lista_de_clientes()
    {
        await using var kit = await StartAsync(postgres);
        var ids = Enumerable.Range(0, 5).Select(_ => Guid.CreateVersion7()).ToArray();
        await kit.PushOkAsync(
            kit.Owner,
            ids.Select((id, i) => SyncOp("client.create", id, ClientPayload($"C{i}"))).Concat(
            [
                SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(ids[0], 1500)),
                SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(ids[1], 2500)),
                SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(ids[1], 300)),
                SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(ids[2], 900)),
            ]).ToArray());

        var summary = await GetSummary(kit, kit.Owner);
        var list = await ApiTestHost.JsonOf(await kit.Host.GetAsync("/api/clients", kit.Owner.Token, kit.BusinessId));

        var balances = list.EnumerateArray().Select(c => c.GetProperty("balance").GetInt64()).ToArray();
        Assert.Equal(balances.Where(b => b > 0).Sum(), summary.GetProperty("debtTotal").GetInt64());
        Assert.Equal(-balances.Where(b => b < 0).Sum(), summary.GetProperty("creditTotal").GetInt64());
    }

    [Fact]
    public async Task El_limite_recorta_la_lista_de_deudores_pero_no_los_totales()
    {
        await using var kit = await StartAsync(postgres);
        for (var i = 1; i <= 5; i++)
        {
            Seed(kit, kit.Owner, Guid.CreateVersion7(), $"C{i}", i * 1000, false);
        }
        await kit.Host.Db.SaveChangesAsync();

        var summary = await GetSummary(kit, kit.Owner, "?limit=2");

        Assert.Equal([5000L, 4000L], summary.GetProperty("debtors").EnumerateArray().Select(d => d.GetProperty("debt").GetInt64()).ToArray());
        Assert.Equal(15000L, summary.GetProperty("debtTotal").GetInt64());
    }

    [Theory]
    [InlineData("?limit=0")]
    [InlineData("?limit=-3")]
    [InlineData("?limit=muchos")]
    public async Task Un_limite_invalido_responde_400(string query)
    {
        await using var kit = await StartAsync(postgres);

        var response = await kit.Host.GetAsync("/api/summary" + query, kit.Owner.Token, kit.BusinessId);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Solo_cuenta_el_negocio_de_la_peticion_y_exige_sesion_y_pertenencia()
    {
        await using var kit = await StartAsync(postgres);
        var stranger = await RegisterAsync(kit.Host, "otra@correo.com");
        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var carla = await kit.AddEmployeeAsync("carla@correo.com");
        await kit.RemoveAsync(carla);
        Seed(kit, kit.Owner, Guid.CreateVersion7(), "Mía", 1000, false);
        Seed(kit, stranger, Guid.CreateVersion7(), "Ajena", 777000, false);
        await kit.Host.Db.SaveChangesAsync();

        var mine = await GetSummary(kit, kit.Owner);
        var asEmployee = await kit.Host.GetAsync("/api/summary", beto.Token, kit.BusinessId);
        var removed = await kit.Host.GetAsync("/api/summary", carla.Token, kit.BusinessId);
        var foreign = await kit.Host.GetAsync("/api/summary", stranger.Token, kit.BusinessId);
        var anonymous = await kit.Host.GetAsync("/api/summary", null, kit.BusinessId);

        Assert.Equal(1000L, mine.GetProperty("debtTotal").GetInt64());
        Assert.Equal(
            [HttpStatusCode.OK, HttpStatusCode.Forbidden, HttpStatusCode.Forbidden, HttpStatusCode.Unauthorized],
            [asEmployee.StatusCode, removed.StatusCode, foreign.StatusCode, anonymous.StatusCode]);
    }
}
