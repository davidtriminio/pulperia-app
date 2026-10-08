using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Operations;
using Pulperia.Domain.Sync;
using Pulperia.Infrastructure.Operations;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;

namespace Pulperia.Tests.Operations;

/// <summary>T062: cada operación aplicada deja su fila en <c>change_log</c> con su <c>seq</c>, de forma atómica.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ChangeLogOperationTests(PostgresFixture postgres)
{
    private static Task<List<(long Seq, ChangeEntityType Type, Guid EntityId)>> Log(OperationKit kit) =>
        kit.Db.ChangeLog.AsNoTracking().OrderBy(c => c.Seq)
            .Select(c => new ValueTuple<long, ChangeEntityType, Guid>(c.Seq, c.EntityType, c.EntityId)).ToListAsync();

    private static Task<long> LastSeq(OperationKit kit) =>
        kit.Db.Businesses.AsNoTracking().Where(b => b.Id == kit.BusinessId).Select(b => b.LastSeq).SingleAsync();

    [Fact]
    public async Task Cada_operacion_aplicada_deja_una_fila_con_el_siguiente_seq_y_su_entidad()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var productId = await kit.NewProductAsync();
        var fiadoId = Guid.CreateVersion7();
        var paymentId = Guid.CreateVersion7();
        await kit.Applier.ApplyAsync(Op("fiado.create", fiadoId, FiadoPayload(clientId, 2500, Item())), kit.Owner);
        await kit.Applier.ApplyAsync(Op("payment.create", paymentId, PaymentPayload(clientId, 500)), kit.Owner);
        await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId), kit.Owner);
        await kit.Applier.ApplyAsync(Op("client.update", clientId, ClientPayload("Ana M."), baseVersion: 1), kit.Owner);

        var log = await Log(kit);

        Assert.Equal(
            new (long, ChangeEntityType, Guid)[]
            {
                (1, ChangeEntityType.Client, clientId),
                (2, ChangeEntityType.Product, productId),
                (3, ChangeEntityType.Fiado, fiadoId),
                (4, ChangeEntityType.Payment, paymentId),
                (5, ChangeEntityType.Fiado, fiadoId),
                (6, ChangeEntityType.Client, clientId),
            },
            log);
        Assert.Equal(6, await LastSeq(kit));
    }

    [Fact]
    public async Task Las_operaciones_rechazadas_y_las_que_no_cambian_nada_no_consumen_seq()
    {
        await using var kit = await CreateAsync(postgres);
        var clientId = await kit.NewClientAsync();
        var fiadoId = Guid.CreateVersion7();
        await kit.Applier.ApplyAsync(Op("fiado.create", fiadoId, FiadoPayload(clientId, 2500, Item())), kit.Owner);
        await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId), kit.Owner);
        var before = await LastSeq(kit);

        var rejected = await kit.Applier.ApplyAsync(
            Op("client.update", clientId, ClientPayload("Otra"), baseVersion: 99), kit.Owner);
        var forbidden = await kit.Applier.ApplyAsync(Op("client.archive", clientId, baseVersion: 1), kit.Employee);
        var annulAgain = await kit.Applier.ApplyAsync(Op("fiado.annul", fiadoId), kit.Owner);
        var restoreActive = await kit.Applier.ApplyAsync(Op("client.restore", clientId, baseVersion: 1), kit.Owner);

        Assert.False(rejected.IsApplied);
        Assert.False(forbidden.IsApplied);
        Assert.True(annulAgain.IsApplied);
        Assert.True(restoreActive.IsApplied);
        Assert.Equal(before, await LastSeq(kit));
        Assert.Equal(3, (await Log(kit)).Count);
    }

    [Fact]
    public async Task Una_falla_a_mitad_de_operacion_no_deja_seq_huerfano_ni_la_entidad_guardada()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.NewClientAsync("Primero");
        Assert.Equal(1, await LastSeq(kit));
        // La base falla justo al escribir la fila del registro, cuando la entidad ya se guardó y
        // el contador ya subió: todo debe deshacerse.
        await kit.Db.Database.ExecuteSqlRawAsync(
            """
            CREATE FUNCTION fail_change_log() RETURNS trigger AS $$
            BEGIN RAISE EXCEPTION 'falla simulada'; END $$ LANGUAGE plpgsql;
            CREATE TRIGGER fail_change_log BEFORE INSERT ON change_log
            FOR EACH ROW EXECUTE FUNCTION fail_change_log();
            """);
        var clientId = Guid.CreateVersion7();

        await Assert.ThrowsAnyAsync<Exception>(() =>
            kit.Applier.ApplyAsync(Op("client.create", clientId, ClientPayload("Segundo")), kit.Owner));

        Assert.Equal(1, await LastSeq(kit));
        Assert.Single(await Log(kit));
        Assert.False(await kit.Db.Clients.AsNoTracking().AnyAsync(c => c.Id == clientId));

        // Al volver la base, el reintento toma el seq siguiente sin hueco.
        await kit.Db.Database.ExecuteSqlRawAsync("DROP TRIGGER fail_change_log ON change_log");
        Assert.True((await kit.Applier.ApplyAsync(Op("client.create", clientId, ClientPayload("Segundo")), kit.Owner)).IsApplied);
        Assert.Equal([1L, 2L], (await Log(kit)).Select(c => c.Seq));
    }

    [Fact]
    public async Task Dos_conexiones_aplicando_a_la_vez_al_mismo_negocio_obtienen_seq_unicos_y_sin_huecos()
    {
        await using var kit = await CreateAsync(postgres);
        const int perWorker = 15;
        var connectionString = kit.Db.Database.GetConnectionString()!;

        async Task Worker()
        {
            await using var db = PostgresFixture.NewContext(connectionString).WithBusiness(kit.BusinessId);
            var applier = new OperationApplier(new EfOperationStore(db));
            for (var i = 0; i < perWorker; i++)
            {
                var result = await applier.ApplyAsync(
                    Op("client.create", Guid.CreateVersion7(), ClientPayload($"Cliente {i}")), kit.Owner);
                Assert.True(result.IsApplied, result.Code);
            }
        }

        await Task.WhenAll(Worker(), Worker());

        var seqs = (await Log(kit)).Select(c => c.Seq).ToList();
        Assert.Equal(Enumerable.Range(1, 2 * perWorker).Select(n => (long)n), seqs);
        Assert.Equal(2 * perWorker, await LastSeq(kit));
    }

    [Fact]
    public async Task Cada_negocio_lleva_su_propio_contador_en_la_misma_base()
    {
        await using var kit = await CreateAsync(postgres);
        var otherBusiness = new Pulperia.Infrastructure.Persistence.Entities.BusinessEntity
        {
            Id = Guid.CreateVersion7(), Name = "Otra pulpería",
            AmountMode = Pulperia.Domain.Business.AmountMode.TwoDecimals,
            QuantityMode = Pulperia.Domain.Business.QuantityMode.Fractional, CreatedAt = At.UtcDateTime,
        };
        kit.Db.Businesses.Add(otherBusiness);
        await kit.Db.SaveChangesAsync();
        await using var otherDb = PostgresFixture.NewContext(kit.Db.Database.GetConnectionString()!).WithBusiness(otherBusiness.Id);
        var otherApplier = new OperationApplier(new EfOperationStore(otherDb));

        await kit.NewClientAsync();
        await kit.NewClientAsync();
        Assert.True((await otherApplier.ApplyAsync(
            Op("client.create", Guid.CreateVersion7(), ClientPayload("De la otra")), kit.Owner)).IsApplied);

        Assert.Equal(2, await LastSeq(kit));
        Assert.Equal([1L, 2L], (await Log(kit)).Select(c => c.Seq));
        var otherSeq = await otherDb.Businesses.AsNoTracking().Where(b => b.Id == otherBusiness.Id).Select(b => b.LastSeq).SingleAsync();
        Assert.Equal(1, otherSeq);
        Assert.Equal([1L], await otherDb.ChangeLog.AsNoTracking().Select(c => c.Seq).ToListAsync());
    }
}
