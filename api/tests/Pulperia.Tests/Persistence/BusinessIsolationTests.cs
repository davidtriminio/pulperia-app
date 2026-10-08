using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Sync;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Persistence;

/// <summary>
/// T055 (RF-50, RNF-6): un negocio nunca ve, modifica ni recibe datos de otro. Con dos
/// negocios llenos de datos, ninguna consulta de un negocio devuelve filas del otro.
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class BusinessIsolationTests(PostgresFixture postgres)
{
    private static readonly DateTime Now = new(2026, 10, 8, 12, 0, 0, DateTimeKind.Utc);

    private sealed record Tenant(
        Guid BusinessId, Guid ClientId, Guid ProductId, Guid FiadoId, Guid ItemId, Guid PaymentId, Guid OpId);

    private sealed record TwoBusinesses(string ConnectionString, Tenant A, Tenant B);

    /// <summary>Dos negocios completos, creados con un contexto sin negocio (cuentas y administración).</summary>
    private async Task<TwoBusinesses> SeedTwoBusinesses()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var user = new UserEntity { Id = Guid.CreateVersion7(), Email = "ana@correo.com", PasswordHash = "h", CreatedAt = Now };
        db.Users.Add(user);

        Tenant Seed(string name, decimal marker)
        {
            var business = new BusinessEntity
            {
                Id = Guid.CreateVersion7(), Name = name, AmountMode = AmountMode.TwoDecimals,
                QuantityMode = QuantityMode.Fractional, CreatedAt = Now,
            };
            var client = new ClientEntity
            {
                Id = Guid.CreateVersion7(), BusinessId = business.Id, Name = $"Cliente de {name}", CharacterId = "char-01",
                SkinId = "skin-1", BackgroundId = "bg-01", CreatedBy = user.Id, CreatedAt = Now, UpdatedAt = Now,
            };
            var product = new ProductEntity
            {
                Id = Guid.CreateVersion7(), BusinessId = business.Id, Name = $"Producto de {name}", Price = 1000,
                CreatedBy = user.Id, CreatedAt = Now,
            };
            var fiado = new FiadoEntity
            {
                Id = Guid.CreateVersion7(), BusinessId = business.Id, ClientId = client.Id, Total = (long)marker,
                OccurredAt = Now, CreatedBy = user.Id,
            };
            var item = new FiadoItemEntity
            {
                Id = Guid.CreateVersion7(), BusinessId = business.Id, FiadoId = fiado.Id, ProductId = product.Id,
                Description = $"Ítem de {name}", Quantity = 1000, Unit = SaleUnit.Unit, UnitPrice = (long)marker, Subtotal = (long)marker,
            };
            var payment = new PaymentEntity
            {
                Id = Guid.CreateVersion7(), BusinessId = business.Id, ClientId = client.Id, Amount = (long)marker / 2,
                OccurredAt = Now, CreatedBy = user.Id,
            };
            var op = new ProcessedOpEntity { OpId = Guid.CreateVersion7(), BusinessId = business.Id, Result = "applied", ProcessedAt = Now };
            db.Businesses.Add(business);
            db.Clients.Add(client);
            db.Products.Add(product);
            db.Fiados.Add(fiado);
            db.Payments.Add(payment);
            db.ProcessedOps.Add(op);
            db.FiadoItems.Add(item);
            db.ChangeLog.Add(new ChangeLogEntity { BusinessId = business.Id, Seq = 1, EntityType = ChangeEntityType.Fiado, EntityId = fiado.Id });
            return new Tenant(business.Id, client.Id, product.Id, fiado.Id, item.Id, payment.Id, op.OpId);
        }

        var a = Seed("Negocio A", 10_000);
        var b = Seed("Negocio B", 70_000);
        await db.SaveChangesAsync();
        return new TwoBusinesses(db.Database.GetConnectionString()!, a, b);
    }

    private static PulperiaDbContext Scoped(TwoBusinesses data, Tenant tenant) =>
        PostgresFixture.NewContext(data.ConnectionString).WithBusiness(tenant.BusinessId);

    // ---- cada negocio solo ve lo suyo

    [Fact]
    public async Task Un_negocio_solo_ve_sus_clientes_productos_fiados_items_abonos_cambios_y_operaciones()
    {
        var data = await SeedTwoBusinesses();

        foreach (var (mine, other) in new[] { (data.A, data.B), (data.B, data.A) })
        {
            await using var db = Scoped(data, mine);

            Assert.Equal([mine.ClientId], await db.Clients.Select(x => x.Id).ToListAsync());
            Assert.Equal([mine.ProductId], await db.Products.Select(x => x.Id).ToListAsync());
            Assert.Equal([mine.FiadoId], await db.Fiados.Select(x => x.Id).ToListAsync());
            Assert.Equal([mine.ItemId], await db.FiadoItems.Select(x => x.Id).ToListAsync());
            Assert.Equal([mine.PaymentId], await db.Payments.Select(x => x.Id).ToListAsync());
            Assert.Equal([mine.OpId], await db.ProcessedOps.Select(x => x.OpId).ToListAsync());
            Assert.All(await db.ChangeLog.ToListAsync(), c => Assert.Equal(mine.BusinessId, c.BusinessId));
            Assert.Equal(1, await db.ChangeLog.CountAsync());
            Assert.DoesNotContain(await db.Clients.ToListAsync(), c => c.BusinessId == other.BusinessId);
        }
    }

    [Fact]
    public async Task Buscar_por_id_un_registro_de_otro_negocio_no_lo_encuentra()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);

        Assert.Null(await db.Clients.SingleOrDefaultAsync(c => c.Id == data.B.ClientId));
        Assert.Null(await db.Products.SingleOrDefaultAsync(p => p.Id == data.B.ProductId));
        Assert.Null(await db.Fiados.SingleOrDefaultAsync(f => f.Id == data.B.FiadoId));
        Assert.Null(await db.FiadoItems.SingleOrDefaultAsync(i => i.Id == data.B.ItemId));
        Assert.Null(await db.Payments.SingleOrDefaultAsync(p => p.Id == data.B.PaymentId));
        Assert.Null(await db.ProcessedOps.SingleOrDefaultAsync(o => o.OpId == data.B.OpId));
        Assert.Null(await db.Clients.FindAsync(data.B.ClientId));
        Assert.False(await db.Clients.AnyAsync(c => c.Id == data.B.ClientId));
    }

    [Fact]
    public async Task Las_sumas_y_agrupaciones_solo_cuentan_el_negocio_activo()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);

        Assert.Equal(10_000, await db.Fiados.SumAsync(f => f.Total));
        Assert.Equal(5_000, await db.Payments.SumAsync(p => p.Amount));
        var groups = await db.Fiados.GroupBy(f => f.BusinessId).Select(g => g.Key).ToListAsync();
        Assert.Equal([data.A.BusinessId], groups);
    }

    [Fact]
    public async Task Los_joins_entre_tablas_tampoco_filtran_datos_del_otro_negocio()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);

        var joined = await (
            from f in db.Fiados
            join c in db.Clients on f.ClientId equals c.Id
            join i in db.FiadoItems on f.Id equals i.FiadoId
            select new { f.BusinessId, c.Name, i.Description }).ToListAsync();

        var row = Assert.Single(joined);
        Assert.Equal(data.A.BusinessId, row.BusinessId);
        Assert.Equal("Cliente de Negocio A", row.Name);
        Assert.Equal("Ítem de Negocio A", row.Description);
    }

    // ---- sin negocio no se ve nada

    [Fact]
    public async Task Sin_negocio_las_tablas_de_negocio_no_devuelven_nada()
    {
        var data = await SeedTwoBusinesses();
        await using var db = PostgresFixture.NewContext(data.ConnectionString);

        Assert.Null(db.BusinessScope);
        Assert.Empty(await db.Clients.ToListAsync());
        Assert.Empty(await db.Products.ToListAsync());
        Assert.Empty(await db.Fiados.ToListAsync());
        Assert.Empty(await db.FiadoItems.ToListAsync());
        Assert.Empty(await db.Payments.ToListAsync());
        Assert.Empty(await db.ChangeLog.ToListAsync());
        Assert.Empty(await db.ProcessedOps.ToListAsync());
    }

    [Fact]
    public async Task Sin_negocio_siguen_visibles_cuentas_y_negocios_para_iniciar_sesion_y_elegir()
    {
        var data = await SeedTwoBusinesses();
        await using var db = PostgresFixture.NewContext(data.ConnectionString);

        Assert.Equal(1, await db.Users.CountAsync());
        Assert.Equal(2, await db.Businesses.CountAsync());
    }

    [Fact]
    public async Task Solo_quien_pide_explicitamente_ignorar_el_filtro_ve_los_dos_negocios()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);

        Assert.Equal(1, await db.Clients.CountAsync());
        Assert.Equal(2, await db.Clients.IgnoreQueryFilters().CountAsync());
    }

    // ---- el negocio activo no se cambia

    [Fact]
    public async Task El_negocio_activo_de_un_contexto_no_puede_cambiar()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);

        Assert.Equal(data.A.BusinessId, db.BusinessScope);
        db.WithBusiness(data.A.BusinessId); // el mismo, sin problema
        Assert.Throws<InvalidOperationException>(() => db.WithBusiness(data.B.BusinessId));
        Assert.Equal(data.A.BusinessId, db.BusinessScope);
    }

    [Fact]
    public async Task Un_negocio_vacio_no_es_un_negocio_valido()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        Assert.Throws<ArgumentException>(() => db.WithBusiness(Guid.Empty));
    }

    // ---- escrituras

    [Fact]
    public async Task Un_negocio_no_puede_crear_registros_a_nombre_de_otro()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);
        var userId = await db.Users.Select(u => u.Id).SingleAsync();
        db.Clients.Add(new ClientEntity
        {
            Id = Guid.CreateVersion7(), BusinessId = data.B.BusinessId, Name = "Intruso", CharacterId = "char-01",
            SkinId = "skin-1", BackgroundId = "bg-01", CreatedBy = userId, CreatedAt = Now, UpdatedAt = Now,
        });

        await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());

        await using var check = Scoped(data, data.B);
        Assert.Equal(1, await check.Clients.CountAsync());
    }

    [Fact]
    public async Task Un_negocio_no_puede_modificar_un_registro_de_otro_aunque_lo_tenga_a_mano()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);
        var foreign = new ProductEntity
        {
            Id = data.B.ProductId, BusinessId = data.B.BusinessId, Name = "Hackeado", Price = 1,
            CreatedBy = Guid.Empty, CreatedAt = Now,
        };
        db.Attach(foreign).State = EntityState.Modified;

        await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());

        await using var check = Scoped(data, data.B);
        Assert.Equal("Producto de Negocio B", (await check.Products.SingleAsync()).Name);
    }

    [Fact]
    public async Task Un_negocio_si_puede_escribir_sus_propios_registros()
    {
        var data = await SeedTwoBusinesses();
        await using var db = Scoped(data, data.A);
        var client = await db.Clients.SingleAsync();

        client.Name = "Nuevo nombre";
        client.Version = 2;
        await db.SaveChangesAsync();

        await using var check = Scoped(data, data.A);
        Assert.Equal("Nuevo nombre", (await check.Clients.SingleAsync()).Name);
    }

    [Fact]
    public async Task El_contador_de_cambios_de_cada_negocio_es_independiente()
    {
        var data = await SeedTwoBusinesses();
        await using var a = Scoped(data, data.A);
        await using var b = Scoped(data, data.B);

        Assert.Equal(1, await ChangeSequence.NextAsync(a, data.A.BusinessId));
        Assert.Equal(2, await ChangeSequence.NextAsync(a, data.A.BusinessId));
        Assert.Equal(1, await ChangeSequence.NextAsync(b, data.B.BusinessId));
    }

    // ---- principio 6: toda tabla de negocio lleva business_id

    [Fact]
    public async Task Toda_tabla_lleva_business_id_salvo_las_de_cuentas_y_administracion()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        HashSet<string> withoutBusinessId = ["users", "sessions", "businesses", "admin_audit", "__EFMigrationsHistory"];

        var tables = await db.Database
            .SqlQueryRaw<string>("SELECT table_name AS \"Value\" FROM information_schema.tables WHERE table_schema = 'public'")
            .ToListAsync();
        var withColumn = await db.Database
            .SqlQueryRaw<string>("SELECT table_name AS \"Value\" FROM information_schema.columns WHERE table_schema = 'public' AND column_name = 'business_id'")
            .ToListAsync();

        var missing = tables.Where(t => !withoutBusinessId.Contains(t) && !withColumn.Contains(t)).ToList();
        Assert.Empty(missing);
    }

    [Fact]
    public async Task Toda_tabla_de_datos_de_negocio_esta_protegida_por_el_filtro()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var protectedTypes = db.Model.GetEntityTypes()
            .Where(t => t.GetDeclaredQueryFilters().Count > 0)
            .Select(t => t.GetTableName()!)
            .ToHashSet();

        HashSet<string> expected =
            ["clients", "products", "fiados", "fiado_items", "payments", "change_log", "processed_ops"];
        Assert.Equal(expected, protectedTypes);
    }
}
