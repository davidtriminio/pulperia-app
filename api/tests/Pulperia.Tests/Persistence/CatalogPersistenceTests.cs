using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Domain.Catalog;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Persistence;

/// <summary>T052: clientes y productos contra un PostgreSQL real (D-25).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class CatalogPersistenceTests(PostgresFixture postgres)
{
    private static readonly DateTime Now = new(2026, 10, 8, 12, 0, 0, DateTimeKind.Utc);

    private const string CheckViolation = "23514";
    private const string UniqueViolation = "23505";
    private const string ForeignKeyViolation = "23503";

    private async Task<(PulperiaDbContext Db, Guid UserId, Guid BusinessId)> Setup()
    {
        var db = await postgres.CreateDatabaseAsync();
        var user = new UserEntity { Id = Guid.CreateVersion7(), Email = "ana@correo.com", PasswordHash = "h", CreatedAt = Now };
        var business = new BusinessEntity
        {
            Id = Guid.CreateVersion7(),
            Name = "Pulpería Ana",
            AmountMode = Pulperia.Domain.Business.AmountMode.TwoDecimals,
            QuantityMode = Pulperia.Domain.Business.QuantityMode.Fractional,
            CreatedAt = Now,
        };
        db.Users.Add(user);
        db.Businesses.Add(business);
        await db.SaveChangesAsync();
        return (db, user.Id, business.Id);
    }

    private static ClientEntity Client(Guid businessId, Guid createdBy, string name = "Ana López") => new()
    {
        Id = Guid.CreateVersion7(),
        BusinessId = businessId,
        Name = name,
        CharacterId = "char-01",
        SkinId = "skin-1",
        BackgroundId = "bg-01",
        CreatedBy = createdBy,
        CreatedAt = Now,
        UpdatedAt = Now,
    };

    private static ProductEntity Product(Guid businessId, Guid createdBy, string name = "Arroz") => new()
    {
        Id = Guid.CreateVersion7(),
        BusinessId = businessId,
        Name = name,
        Price = 2500,
        CreatedBy = createdBy,
        CreatedAt = Now,
    };

    private static async Task ThrowsPostgresAsync(Func<Task> action, string sqlState)
    {
        var ex = await Assert.ThrowsAsync<DbUpdateException>(action);
        var pg = Assert.IsType<PostgresException>(ex.InnerException);
        Assert.Equal(sqlState, pg.SqlState);
    }

    private static async Task<List<string>> Columns(PulperiaDbContext db, string table) =>
        await db.Database
            .SqlQueryRaw<string>($"SELECT column_name AS \"Value\" FROM information_schema.columns WHERE table_name = '{table}'")
            .ToListAsync();

    // ---- esquema (plan 3.1)

    [Fact]
    public async Task La_tabla_de_clientes_tiene_las_columnas_del_plan()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        Assert.Equivalent(
            new[]
            {
                "id", "business_id", "name", "character_id", "skin_id", "background_id", "phone", "address",
                "note", "archived", "version", "created_by", "created_at", "updated_at",
            },
            await Columns(db, "clients"));
    }

    [Fact]
    public async Task La_tabla_de_productos_tiene_las_columnas_del_plan_con_el_precio_anterior()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        Assert.Equivalent(
            new[]
            {
                "id", "business_id", "name", "price", "unit", "previous_price", "price_changed_at",
                "archived", "version", "created_by", "created_at",
            },
            await Columns(db, "products"));
    }

    [Fact]
    public async Task El_modelo_sigue_sin_cambios_pendientes_de_migrar()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        Assert.False(db.Database.HasPendingModelChanges());
    }

    // ---- clientes (RF-14 a RF-23, RF-73, RF-74, RF-77)

    [Fact]
    public async Task Un_cliente_se_crea_y_se_lee_con_todos_sus_campos()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        client.Phone = "90000000";
        client.Address = "Frente a la iglesia";
        client.Note = "Paga los viernes";
        db.Clients.Add(client);
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Clients.SingleAsync(c => c.Id == client.Id);

        Assert.Equal("Ana López", read.Name);
        Assert.Equal(("char-01", "skin-1", "bg-01"), (read.CharacterId, read.SkinId, read.BackgroundId));
        Assert.Equal("90000000", read.Phone);
        Assert.Equal("Frente a la iglesia", read.Address);
        Assert.Equal("Paga los viernes", read.Note);
        Assert.False(read.Archived);
        Assert.Equal(1, read.Version);
        Assert.Equal(userId, read.CreatedBy);
        Assert.Equal(Now, read.CreatedAt);
        Assert.Equal(Now, read.UpdatedAt);
    }

    [Fact]
    public async Task Telefono_direccion_y_nota_son_opcionales_RF73()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        db.Clients.Add(client);
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Clients.SingleAsync();

        Assert.Null(read.Phone);
        Assert.Null(read.Address);
        Assert.Null(read.Note);
    }

    [Fact]
    public async Task Archivar_un_cliente_lo_marca_sin_borrarlo_RF20()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        db.Clients.Add(client);
        await db.SaveChangesAsync();

        client.Archived = true;
        client.Version = 2;
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Clients.SingleAsync();
        Assert.True(read.Archived);
        Assert.Equal(2, read.Version);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task El_nombre_del_cliente_es_obligatorio_RF15(string name)
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        db.Clients.Add(Client(businessId, userId, name));

        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Theory]
    [InlineData("12345678")]
    [InlineData("9000000")]
    [InlineData("900000000")]
    [InlineData("9000000a")]
    [InlineData("90000000 ")]
    public async Task Un_telefono_con_formato_invalido_se_rechaza_RF77(string phone)
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        client.Phone = phone;
        db.Clients.Add(client);

        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Theory]
    [InlineData("20000000")]
    [InlineData("30000000")]
    [InlineData("80000000")]
    [InlineData("90000000")]
    public async Task Los_telefonos_validos_se_guardan_RF77(string phone)
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        client.Phone = phone;
        db.Clients.Add(client);

        await db.SaveChangesAsync();
    }

    [Fact]
    public async Task La_nota_admite_300_caracteres_y_no_301_RF74()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var ok = Client(businessId, userId);
        ok.Note = new string('n', 300);
        db.Clients.Add(ok);
        await db.SaveChangesAsync();

        var tooLong = Client(businessId, userId, "Otra");
        tooLong.Note = new string('n', 301);
        db.Clients.Add(tooLong);
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Dos_clientes_pueden_llamarse_igual_RF17()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        db.Clients.AddRange(Client(businessId, userId, "Ana López"), Client(businessId, userId, "Ana López"));

        await db.SaveChangesAsync();

        Assert.Equal(2, await db.Clients.CountAsync());
    }

    [Fact]
    public async Task Un_cliente_exige_negocio_y_creador_existentes()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        db.Clients.Add(Client(Guid.CreateVersion7(), userId));
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), ForeignKeyViolation);

        db.ChangeTracker.Clear();
        db.Clients.Add(Client(businessId, Guid.CreateVersion7()));
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task La_version_no_baja_de_uno()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        client.Version = 0;
        db.Clients.Add(client);

        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task El_par_id_y_negocio_es_unico_para_que_otras_tablas_lo_referencien()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        db.Clients.Add(client);
        await db.SaveChangesAsync();

        var indexes = await db.Database
            .SqlQueryRaw<string>("SELECT indexname AS \"Value\" FROM pg_indexes WHERE tablename = 'clients'")
            .ToListAsync();

        Assert.Contains("uq_clients_id_business_id", indexes);
    }

    // ---- productos (RF-24 a RF-27, RF-36, RF-86, RF-90)

    [Fact]
    public async Task Un_producto_se_crea_y_se_lee_con_su_unidad()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var product = Product(businessId, userId);
        product.Unit = SaleUnit.Pound;
        db.Products.Add(product);
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Products.SingleAsync(p => p.Id == product.Id);

        Assert.Equal("Arroz", read.Name);
        Assert.Equal(2500, read.Price);
        Assert.Equal(SaleUnit.Pound, read.Unit);
        Assert.Null(read.PreviousPrice);
        Assert.Null(read.PriceChangedAt);
        Assert.False(read.Archived);
        Assert.Equal(1, read.Version);
        Assert.Equal(Now, read.CreatedAt);
    }

    [Fact]
    public async Task La_unidad_se_guarda_con_su_id_estable_y_es_unidad_por_omision()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        db.Products.Add(Product(businessId, userId));
        await db.SaveChangesAsync();

        var unit = await db.Database.SqlQueryRaw<string>("SELECT unit AS \"Value\" FROM products").SingleAsync();

        Assert.Equal("unit", unit);
    }

    [Fact]
    public async Task Todas_las_unidades_de_la_lista_compartida_se_pueden_guardar_RF86()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        foreach (var unit in Enum.GetValues<SaleUnit>())
        {
            var product = Product(businessId, userId, $"Producto {unit}");
            product.Unit = unit;
            db.Products.Add(product);
        }

        await db.SaveChangesAsync();

        Assert.Equal(10, await db.Products.CountAsync());
    }

    [Fact]
    public async Task Una_unidad_fuera_de_la_lista_se_rechaza_en_la_base()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var id = Guid.CreateVersion7();

        var ex = await Assert.ThrowsAsync<PostgresException>(() => db.Database.ExecuteSqlRawAsync(
            "INSERT INTO products (id, business_id, name, price, unit, archived, version, created_by, created_at) " +
            $"VALUES ('{id}', '{businessId}', 'X', 100, 'galon', false, 1, '{userId}', now())"));

        Assert.Equal(CheckViolation, ex.SqlState);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-100)]
    public async Task El_precio_debe_ser_positivo(long price)
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var product = Product(businessId, userId);
        product.Price = price;
        db.Products.Add(product);

        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task El_nombre_del_producto_es_obligatorio()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        db.Products.Add(Product(businessId, userId, "  "));

        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Cambiar_el_precio_guarda_el_anterior_y_la_fecha_RF90()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var product = Product(businessId, userId);
        db.Products.Add(product);
        await db.SaveChangesAsync();

        product.PreviousPrice = 2500;
        product.Price = 3000;
        product.PriceChangedAt = Now.AddDays(1);
        product.Version = 2;
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Products.SingleAsync();
        Assert.Equal(3000, read.Price);
        Assert.Equal(2500, read.PreviousPrice);
        Assert.Equal(Now.AddDays(1), read.PriceChangedAt);
        Assert.Equal(DateTimeKind.Utc, read.PriceChangedAt!.Value.Kind);
    }

    [Fact]
    public async Task El_precio_anterior_y_su_fecha_van_juntos_o_ninguno_D24()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var onlyPrice = Product(businessId, userId);
        onlyPrice.PreviousPrice = 2000;
        db.Products.Add(onlyPrice);
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);

        db.ChangeTracker.Clear();
        var onlyDate = Product(businessId, userId);
        onlyDate.PriceChangedAt = Now;
        db.Products.Add(onlyDate);
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task El_precio_anterior_debe_ser_positivo()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var product = Product(businessId, userId);
        product.PreviousPrice = 0;
        product.PriceChangedAt = Now;
        db.Products.Add(product);

        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Dos_productos_pueden_tener_el_mismo_nombre_y_unidad_el_aviso_es_del_cliente_RF91()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        db.Products.AddRange(Product(businessId, userId, "Aceite"), Product(businessId, userId, "Aceite"));

        await db.SaveChangesAsync();

        Assert.Equal(2, await db.Products.CountAsync());
    }

    [Fact]
    public async Task Archivar_un_producto_lo_marca_sin_borrarlo_RF26_RF27()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var product = Product(businessId, userId);
        db.Products.Add(product);
        await db.SaveChangesAsync();

        product.Archived = true;
        await db.SaveChangesAsync();

        Assert.True((await db.Products.SingleAsync()).Archived);
    }

    [Fact]
    public async Task Un_producto_exige_negocio_y_creador_existentes()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        db.Products.Add(Product(Guid.CreateVersion7(), userId));
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), ForeignKeyViolation);

        db.ChangeTracker.Clear();
        db.Products.Add(Product(businessId, Guid.CreateVersion7()));
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task El_par_id_y_negocio_de_productos_tambien_es_unico()
    {
        var (db, _, _) = await Setup();
        await using var _db = db;

        var indexes = await db.Database
            .SqlQueryRaw<string>("SELECT indexname AS \"Value\" FROM pg_indexes WHERE tablename = 'products'")
            .ToListAsync();

        Assert.Contains("uq_products_id_business_id", indexes);
    }

    [Fact]
    public async Task Un_mismo_id_no_se_repite_ni_entre_negocios()
    {
        var (db, userId, businessId) = await Setup();
        await using var _ = db;
        var client = Client(businessId, userId);
        db.Clients.Add(client);
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var otherBusiness = new BusinessEntity
        {
            Id = Guid.CreateVersion7(),
            Name = "Otra",
            AmountMode = Pulperia.Domain.Business.AmountMode.Integer,
            QuantityMode = Pulperia.Domain.Business.QuantityMode.Integer,
            CreatedAt = Now,
        };
        other.Businesses.Add(otherBusiness);
        var duplicated = Client(otherBusiness.Id, userId);
        duplicated.Id = client.Id;
        other.Clients.Add(duplicated);

        await ThrowsPostgresAsync(() => other.SaveChangesAsync(), UniqueViolation);
    }
}
