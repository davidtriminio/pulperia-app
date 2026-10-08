using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Ledger;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Persistence;

/// <summary>T053: fiados, ítems y abonos contra un PostgreSQL real (D-25).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class LedgerPersistenceTests(PostgresFixture postgres)
{
    private static readonly DateTime Now = new(2026, 10, 8, 12, 0, 0, DateTimeKind.Utc);

    private const string CheckViolation = "23514";
    private const string ForeignKeyViolation = "23503";
    private const string RestrictViolation = "23001";

    private sealed record World(
        PulperiaDbContext Db, Guid UserId, Guid BusinessId, Guid ClientId, Guid ProductId) : IAsyncDisposable
    {
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private async Task<World> Setup()
    {
        var db = await postgres.CreateDatabaseAsync();
        var user = new UserEntity { Id = Guid.CreateVersion7(), Email = "ana@correo.com", PasswordHash = "h", CreatedAt = Now };
        var business = NewBusiness("Pulpería Ana");
        var client = new ClientEntity
        {
            Id = Guid.CreateVersion7(), BusinessId = business.Id, Name = "Ana López", CharacterId = "char-01",
            SkinId = "skin-1", BackgroundId = "bg-01", CreatedBy = user.Id, CreatedAt = Now, UpdatedAt = Now,
        };
        var product = new ProductEntity
        {
            Id = Guid.CreateVersion7(), BusinessId = business.Id, Name = "Arroz", Price = 2500,
            CreatedBy = user.Id, CreatedAt = Now,
        };
        db.Users.Add(user);
        db.Businesses.Add(business);
        db.Clients.Add(client);
        db.Products.Add(product);
        await db.SaveChangesAsync();
        return new World(db, user.Id, business.Id, client.Id, product.Id);
    }

    private static BusinessEntity NewBusiness(string name) => new()
    {
        Id = Guid.CreateVersion7(), Name = name, AmountMode = AmountMode.TwoDecimals,
        QuantityMode = QuantityMode.Fractional, CreatedAt = Now,
    };

    private static FiadoEntity Fiado(World w, long total = 5000) => new()
    {
        Id = Guid.CreateVersion7(), BusinessId = w.BusinessId, ClientId = w.ClientId, Total = total,
        OccurredAt = Now, CreatedBy = w.UserId,
    };

    private static FiadoItemEntity Item(World w, Guid fiadoId, Guid? productId = null) => new()
    {
        Id = Guid.CreateVersion7(), BusinessId = w.BusinessId, FiadoId = fiadoId, ProductId = productId,
        Description = "Arroz", Quantity = 2000, Unit = SaleUnit.Pound, UnitPrice = 2500, Subtotal = 5000,
    };

    private static PaymentEntity Payment(World w, long amount = 3000) => new()
    {
        Id = Guid.CreateVersion7(), BusinessId = w.BusinessId, ClientId = w.ClientId, Amount = amount,
        OccurredAt = Now, CreatedBy = w.UserId,
    };

    private static async Task ThrowsPostgresAsync(Func<Task> action, string sqlState)
    {
        var ex = await Assert.ThrowsAsync<DbUpdateException>(action);
        var pg = Assert.IsType<PostgresException>(ex.InnerException);
        Assert.Equal(sqlState, pg.SqlState);
    }

    private static async Task ThrowsSqlAsync(PulperiaDbContext db, string sql, string sqlState)
    {
        var ex = await Assert.ThrowsAsync<PostgresException>(() => db.Database.ExecuteSqlRawAsync(sql));
        Assert.Equal(sqlState, ex.SqlState);
    }

    private static async Task<List<string>> Columns(PulperiaDbContext db, string table) =>
        await db.Database
            .SqlQueryRaw<string>($"SELECT column_name AS \"Value\" FROM information_schema.columns WHERE table_name = '{table}'")
            .ToListAsync();

    // ---- esquema (plan 3.1)

    [Fact]
    public async Task Las_tablas_tienen_las_columnas_del_plan()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        Assert.Equivalent(
            new[] { "id", "business_id", "client_id", "total", "occurred_at", "created_by", "annulled_at", "annulled_by" },
            await Columns(db, "fiados"));
        // El plan lista fiado_items sin business_id, pero todo registro de negocio lo lleva (principio 6).
        Assert.Equivalent(
            new[]
            {
                "id", "business_id", "fiado_id", "product_id", "description", "quantity", "unit", "unit_price", "subtotal",
            },
            await Columns(db, "fiado_items"));
        Assert.Equivalent(
            new[] { "id", "business_id", "client_id", "amount", "occurred_at", "created_by", "annulled_at", "annulled_by" },
            await Columns(db, "payments"));
    }

    [Fact]
    public async Task El_modelo_sigue_sin_cambios_pendientes_de_migrar()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        Assert.False(db.Database.HasPendingModelChanges());
    }

    // ---- fiados (RF-28, RF-29)

    [Fact]
    public async Task Un_fiado_se_crea_y_se_lee_con_el_usuario_que_lo_registro_RF49()
    {
        await using var w = await Setup();
        var fiado = Fiado(w, 99_999_999_000);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(w.Db.Database.GetConnectionString()!);
        var read = await other.Fiados.SingleAsync(f => f.Id == fiado.Id);

        Assert.Equal(99_999_999_000, read.Total);
        Assert.Equal(w.ClientId, read.ClientId);
        Assert.Equal(w.UserId, read.CreatedBy);
        Assert.Equal(Now, read.OccurredAt);
        Assert.Equal(DateTimeKind.Utc, read.OccurredAt.Kind);
        Assert.Null(read.AnnulledAt);
        Assert.Null(read.AnnulledBy);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5000)]
    public async Task El_total_del_fiado_debe_ser_positivo(long total)
    {
        await using var w = await Setup();
        w.Db.Fiados.Add(Fiado(w, total));

        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Un_fiado_solo_con_monto_total_no_necesita_items_RF29()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();

        Assert.Equal(0, await w.Db.FiadoItems.CountAsync());
    }

    [Fact]
    public async Task Un_fiado_exige_un_cliente_del_mismo_negocio_RNF6()
    {
        await using var w = await Setup();
        var other = NewBusiness("Otro negocio");
        w.Db.Businesses.Add(other);
        await w.Db.SaveChangesAsync();
        var fiado = Fiado(w);
        fiado.BusinessId = other.Id; // el cliente existe, pero es del negocio de Ana
        w.Db.Fiados.Add(fiado);

        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task Un_fiado_exige_un_cliente_existente_y_un_usuario_existente()
    {
        await using var w = await Setup();
        var noClient = Fiado(w);
        noClient.ClientId = Guid.CreateVersion7();
        w.Db.Fiados.Add(noClient);
        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), ForeignKeyViolation);

        w.Db.ChangeTracker.Clear();
        var noUser = Fiado(w);
        noUser.CreatedBy = Guid.CreateVersion7();
        w.Db.Fiados.Add(noUser);
        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task Se_puede_fiar_a_un_cliente_archivado_RF85()
    {
        await using var w = await Setup();
        var client = await w.Db.Clients.SingleAsync();
        client.Archived = true;
        await w.Db.SaveChangesAsync();
        w.Db.Fiados.Add(Fiado(w));

        await w.Db.SaveChangesAsync();

        Assert.Equal(1, await w.Db.Fiados.CountAsync());
    }

    // ---- ítems (RF-28, RF-31, RF-86, RF-88)

    [Fact]
    public async Task Un_item_conserva_cantidad_precio_unidad_y_subtotal_del_momento()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        var item = Item(w, fiado.Id, w.ProductId);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();
        w.Db.FiadoItems.Add(item);
        await w.Db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(w.Db.Database.GetConnectionString()!);
        var read = await other.FiadoItems.SingleAsync();

        Assert.Equal("Arroz", read.Description);
        Assert.Equal(2000, read.Quantity);
        Assert.Equal(SaleUnit.Pound, read.Unit);
        Assert.Equal(2500, read.UnitPrice);
        Assert.Equal(5000, read.Subtotal);
        Assert.Equal(w.ProductId, read.ProductId);
    }

    [Fact]
    public async Task Un_item_libre_no_tiene_producto_RF31()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();
        w.Db.FiadoItems.Add(Item(w, fiado.Id, null));

        await w.Db.SaveChangesAsync();

        Assert.Null((await w.Db.FiadoItems.SingleAsync()).ProductId);
    }

    [Fact]
    public async Task La_unidad_del_item_se_guarda_con_su_id_estable()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();
        w.Db.FiadoItems.Add(Item(w, fiado.Id));
        await w.Db.SaveChangesAsync();

        var unit = await w.Db.Database.SqlQueryRaw<string>("SELECT unit AS \"Value\" FROM fiado_items").SingleAsync();

        Assert.Equal("pound", unit);
    }

    [Theory]
    [InlineData("quantity", 0)]
    [InlineData("quantity", -1000)]
    [InlineData("unit_price", 0)]
    [InlineData("subtotal", 0)]
    [InlineData("subtotal", -100)]
    public async Task Cantidad_precio_y_subtotal_del_item_deben_ser_positivos(string column, long value)
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();
        var id = Guid.CreateVersion7();
        var values = new Dictionary<string, long> { ["quantity"] = 1000, ["unit_price"] = 2500, ["subtotal"] = 2500 };
        values[column] = value;

        await ThrowsSqlAsync(
            w.Db,
            "INSERT INTO fiado_items (id, business_id, fiado_id, description, quantity, unit, unit_price, subtotal) " +
            $"VALUES ('{id}', '{w.BusinessId}', '{fiado.Id}', 'X', {values["quantity"]}, 'unit', {values["unit_price"]}, {values["subtotal"]})",
            CheckViolation);
    }

    [Fact]
    public async Task Una_unidad_fuera_de_la_lista_se_rechaza_en_el_item()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();
        var id = Guid.CreateVersion7();

        await ThrowsSqlAsync(
            w.Db,
            "INSERT INTO fiado_items (id, business_id, fiado_id, description, quantity, unit, unit_price, subtotal) " +
            $"VALUES ('{id}', '{w.BusinessId}', '{fiado.Id}', 'X', 1000, 'galon', 100, 100)",
            CheckViolation);
    }

    [Fact]
    public async Task Un_item_exige_un_fiado_y_un_producto_del_mismo_negocio_RNF6()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        var other = NewBusiness("Otro negocio");
        w.Db.Businesses.Add(other);
        await w.Db.SaveChangesAsync();

        var wrongBusiness = Item(w, fiado.Id);
        wrongBusiness.BusinessId = other.Id;
        w.Db.FiadoItems.Add(wrongBusiness);
        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), ForeignKeyViolation);

        w.Db.ChangeTracker.Clear();
        var otherProduct = new ProductEntity
        {
            Id = Guid.CreateVersion7(), BusinessId = other.Id, Name = "Ajeno", Price = 100,
            CreatedBy = w.UserId, CreatedAt = Now,
        };
        w.Db.Products.Add(otherProduct);
        await w.Db.SaveChangesAsync();
        w.Db.FiadoItems.Add(Item(w, fiado.Id, otherProduct.Id));
        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), ForeignKeyViolation);
    }

    // ---- abonos (RF-37, RF-38, RF-39)

    [Fact]
    public async Task Un_abono_se_crea_y_se_lee_con_el_usuario_que_lo_registro_RF49()
    {
        await using var w = await Setup();
        var payment = Payment(w);
        w.Db.Payments.Add(payment);
        await w.Db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(w.Db.Database.GetConnectionString()!);
        var read = await other.Payments.SingleAsync();

        Assert.Equal(3000, read.Amount);
        Assert.Equal(w.ClientId, read.ClientId);
        Assert.Equal(w.UserId, read.CreatedBy);
        Assert.Equal(Now, read.OccurredAt);
        Assert.Null(read.AnnulledAt);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task El_monto_del_abono_debe_ser_positivo_RF38(long amount)
    {
        await using var w = await Setup();
        w.Db.Payments.Add(Payment(w, amount));

        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Un_abono_puede_ser_mayor_que_la_deuda_y_deja_saldo_a_favor_RF39()
    {
        await using var w = await Setup();
        w.Db.Fiados.Add(Fiado(w, 5000));
        w.Db.Payments.Add(Payment(w, 12000));
        await w.Db.SaveChangesAsync();

        var balance = await BalanceOf(w);

        Assert.Equal(BalanceLabel.Credit, balance.Label);
        Assert.Equal(new Money(7000), balance.Credit);
    }

    [Fact]
    public async Task Un_abono_exige_un_cliente_del_mismo_negocio_RNF6()
    {
        await using var w = await Setup();
        var other = NewBusiness("Otro negocio");
        w.Db.Businesses.Add(other);
        await w.Db.SaveChangesAsync();
        var payment = Payment(w);
        payment.BusinessId = other.Id;
        w.Db.Payments.Add(payment);

        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), ForeignKeyViolation);
    }

    // ---- anulación (RF-43, RF-44, RF-46)

    [Fact]
    public async Task Anular_un_fiado_guarda_quien_y_cuando_y_no_lo_borra_RF43()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();

        fiado.AnnulledAt = Now.AddHours(1);
        fiado.AnnulledBy = w.UserId;
        await w.Db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(w.Db.Database.GetConnectionString()!);
        var read = await other.Fiados.SingleAsync();
        Assert.Equal(Now.AddHours(1), read.AnnulledAt);
        Assert.Equal(w.UserId, read.AnnulledBy);
        Assert.Equal(5000, read.Total);
    }

    [Fact]
    public async Task Anular_un_abono_guarda_quien_y_cuando()
    {
        await using var w = await Setup();
        var payment = Payment(w);
        w.Db.Payments.Add(payment);
        await w.Db.SaveChangesAsync();

        payment.AnnulledAt = Now.AddHours(1);
        payment.AnnulledBy = w.UserId;
        await w.Db.SaveChangesAsync();

        Assert.NotNull((await w.Db.Payments.SingleAsync()).AnnulledAt);
    }

    [Fact]
    public async Task La_fecha_y_el_usuario_de_la_anulacion_van_juntos_o_ninguno()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        fiado.AnnulledAt = Now;
        w.Db.Fiados.Add(fiado);
        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), CheckViolation);

        w.Db.ChangeTracker.Clear();
        var payment = Payment(w);
        payment.AnnulledBy = w.UserId;
        w.Db.Payments.Add(payment);
        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Quien_anula_debe_ser_un_usuario_existente()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        fiado.AnnulledAt = Now;
        fiado.AnnulledBy = Guid.CreateVersion7();
        w.Db.Fiados.Add(fiado);

        await ThrowsPostgresAsync(() => w.Db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task Los_anulados_no_cuentan_para_el_saldo_RF44()
    {
        await using var w = await Setup();
        var annulled = Fiado(w, 4000);
        annulled.AnnulledAt = Now;
        annulled.AnnulledBy = w.UserId;
        w.Db.Fiados.AddRange(Fiado(w, 5000), annulled);
        w.Db.Payments.Add(Payment(w, 1000));
        await w.Db.SaveChangesAsync();

        var balance = await BalanceOf(w);

        Assert.Equal(new Money(4000), balance.Amount);
    }

    private static async Task<Balance> BalanceOf(World w)
    {
        var fiados = await w.Db.Fiados.Where(f => f.ClientId == w.ClientId).ToListAsync();
        var payments = await w.Db.Payments.Where(p => p.ClientId == w.ClientId).ToListAsync();
        return Balances.Compute(fiados.Select(f => f.ToMovement()).Concat(payments.Select(p => p.ToMovement())));
    }

    // ---- no se editan ni se eliminan (RF-46, principio 11, RF-27)

    [Fact]
    public async Task Un_fiado_no_se_edita_RF46()
    {
        await using var w = await Setup();
        w.Db.Fiados.Add(Fiado(w));
        await w.Db.SaveChangesAsync();

        await ThrowsSqlAsync(w.Db, "UPDATE fiados SET total = total + 1", RestrictViolation);
    }

    [Fact]
    public async Task Un_abono_no_se_edita_RF46()
    {
        await using var w = await Setup();
        w.Db.Payments.Add(Payment(w));
        await w.Db.SaveChangesAsync();

        await ThrowsSqlAsync(w.Db, "UPDATE payments SET amount = amount + 1", RestrictViolation);
    }

    [Fact]
    public async Task Un_item_no_se_edita()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();
        w.Db.FiadoItems.Add(Item(w, fiado.Id));
        await w.Db.SaveChangesAsync();

        await ThrowsSqlAsync(w.Db, "UPDATE fiado_items SET unit_price = unit_price + 1", RestrictViolation);
    }

    [Theory]
    [InlineData("fiados")]
    [InlineData("payments")]
    [InlineData("fiado_items")]
    [InlineData("clients")]
    [InlineData("products")]
    public async Task Ningun_registro_se_elimina_RF46_RF27(string table)
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        w.Db.Payments.Add(Payment(w));
        await w.Db.SaveChangesAsync();
        w.Db.FiadoItems.Add(Item(w, fiado.Id));
        await w.Db.SaveChangesAsync();

        await ThrowsSqlAsync(w.Db, $"DELETE FROM {table}", RestrictViolation);
    }

    [Fact]
    public async Task Una_anulacion_ya_hecha_no_se_cambia_ni_se_deshace()
    {
        await using var w = await Setup();
        var fiado = Fiado(w);
        w.Db.Fiados.Add(fiado);
        await w.Db.SaveChangesAsync();
        fiado.AnnulledAt = Now;
        fiado.AnnulledBy = w.UserId;
        await w.Db.SaveChangesAsync();

        await ThrowsSqlAsync(w.Db, "UPDATE fiados SET annulled_at = now()", RestrictViolation);
        await ThrowsSqlAsync(w.Db, "UPDATE fiados SET annulled_at = NULL, annulled_by = NULL", RestrictViolation);
    }

    [Fact]
    public async Task Anular_no_permite_cambiar_a_la_vez_otro_campo()
    {
        await using var w = await Setup();
        w.Db.Fiados.Add(Fiado(w));
        await w.Db.SaveChangesAsync();

        await ThrowsSqlAsync(
            w.Db,
            $"UPDATE fiados SET annulled_at = now(), annulled_by = '{w.UserId}', total = 1",
            RestrictViolation);
    }

    // ---- mapeo con el dominio

    [Fact]
    public void Un_fiado_y_un_abono_se_convierten_en_movimientos_del_dominio()
    {
        var w = new World(null!, Guid.CreateVersion7(), Guid.CreateVersion7(), Guid.CreateVersion7(), Guid.CreateVersion7());
        var fiado = Fiado(w, 5000);
        var annulled = Fiado(w, 4000);
        annulled.AnnulledAt = Now;
        annulled.AnnulledBy = w.UserId;
        var payment = Payment(w, 1500);

        Assert.Equal(new LedgerMovement(MovementKind.Fiado, new Money(5000), false), fiado.ToMovement());
        Assert.Equal(new LedgerMovement(MovementKind.Fiado, new Money(4000), true), annulled.ToMovement());
        Assert.Equal(new LedgerMovement(MovementKind.Payment, new Money(1500), false), payment.ToMovement());
    }
}
