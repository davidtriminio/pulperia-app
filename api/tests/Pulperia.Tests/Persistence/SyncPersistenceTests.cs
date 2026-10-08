using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Domain.Admin;
using Pulperia.Domain.Business;
using Pulperia.Domain.Sync;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Persistence;

/// <summary>
/// T054: registro de cambios, operaciones procesadas, contador por negocio y auditoría
/// contra un PostgreSQL real (D-25).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SyncPersistenceTests(PostgresFixture postgres)
{
    private static readonly DateTime Now = new(2026, 10, 8, 12, 0, 0, DateTimeKind.Utc);

    private const string CheckViolation = "23514";
    private const string UniqueViolation = "23505";
    private const string ForeignKeyViolation = "23503";
    private const string RestrictViolation = "23001";

    private static BusinessEntity NewBusiness(string name = "Pulpería Ana") => new()
    {
        Id = Guid.CreateVersion7(), Name = name, AmountMode = AmountMode.TwoDecimals,
        QuantityMode = QuantityMode.Fractional, CreatedAt = Now,
    };

    private async Task<(PulperiaDbContext Db, BusinessEntity Business)> Setup()
    {
        var db = await postgres.CreateDatabaseAsync();
        var business = NewBusiness();
        db.Businesses.Add(business);
        await db.SaveChangesAsync();
        return (db, business);
    }

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
            new[] { "business_id", "seq", "entity_type", "entity_id" },
            await Columns(db, "change_log"));
        Assert.Equivalent(
            new[] { "op_id", "business_id", "result", "processed_at" },
            await Columns(db, "processed_ops"));
        Assert.Equivalent(
            new[] { "id", "action", "target_user_id", "performed_by", "performed_at" },
            await Columns(db, "admin_audit"));
    }

    [Fact]
    public async Task El_modelo_sigue_sin_cambios_pendientes_de_migrar()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        Assert.False(db.Database.HasPendingModelChanges());
    }

    // ---- registro de cambios (RF-52, T062)

    [Fact]
    public async Task Un_cambio_se_registra_y_se_lee_con_su_tipo_y_entidad()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        var entityId = Guid.CreateVersion7();
        db.ChangeLog.Add(new ChangeLogEntity
        {
            BusinessId = business.Id, Seq = 1, EntityType = ChangeEntityType.Fiado, EntityId = entityId,
        });
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.ChangeLog.IgnoreQueryFilters().SingleAsync();

        Assert.Equal(1, read.Seq);
        Assert.Equal(ChangeEntityType.Fiado, read.EntityType);
        Assert.Equal(entityId, read.EntityId);
        Assert.Equal(business.Id, read.BusinessId);
    }

    [Theory]
    [InlineData(ChangeEntityType.Client, "client")]
    [InlineData(ChangeEntityType.Product, "product")]
    [InlineData(ChangeEntityType.Fiado, "fiado")]
    [InlineData(ChangeEntityType.Payment, "payment")]
    public async Task El_tipo_de_entidad_se_guarda_con_su_id_estable(ChangeEntityType type, string stored)
    {
        var (db, business) = await Setup();
        await using var _ = db;
        db.ChangeLog.Add(new ChangeLogEntity { BusinessId = business.Id, Seq = 1, EntityType = type, EntityId = Guid.CreateVersion7() });
        await db.SaveChangesAsync();

        var value = await db.Database.SqlQueryRaw<string>("SELECT entity_type AS \"Value\" FROM change_log").SingleAsync();

        Assert.Equal(stored, value);
    }

    [Fact]
    public async Task El_seq_es_unico_por_negocio_pero_se_repite_entre_negocios()
    {
        var (db, first) = await Setup();
        await using var _ = db;
        var second = NewBusiness("Otro negocio");
        db.Businesses.Add(second);
        db.ChangeLog.AddRange(
            new ChangeLogEntity { BusinessId = first.Id, Seq = 1, EntityType = ChangeEntityType.Client, EntityId = Guid.CreateVersion7() },
            new ChangeLogEntity { BusinessId = second.Id, Seq = 1, EntityType = ChangeEntityType.Client, EntityId = Guid.CreateVersion7() });
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        other.ChangeLog.Add(new ChangeLogEntity { BusinessId = first.Id, Seq = 1, EntityType = ChangeEntityType.Product, EntityId = Guid.CreateVersion7() });

        await ThrowsPostgresAsync(() => other.SaveChangesAsync(), UniqueViolation);
    }

    [Fact]
    public async Task El_seq_debe_ser_positivo_y_el_negocio_existir()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        db.ChangeLog.Add(new ChangeLogEntity { BusinessId = business.Id, Seq = 0, EntityType = ChangeEntityType.Client, EntityId = Guid.CreateVersion7() });
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);

        db.ChangeTracker.Clear();
        db.ChangeLog.Add(new ChangeLogEntity { BusinessId = Guid.CreateVersion7(), Seq = 1, EntityType = ChangeEntityType.Client, EntityId = Guid.CreateVersion7() });
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task Un_tipo_de_entidad_fuera_de_la_lista_se_rechaza_en_la_base()
    {
        var (db, business) = await Setup();
        await using var _ = db;

        await ThrowsSqlAsync(
            db,
            $"INSERT INTO change_log (business_id, seq, entity_type, entity_id) VALUES ('{business.Id}', 1, 'user', '{Guid.CreateVersion7()}')",
            CheckViolation);
    }

    [Fact]
    public async Task Los_cambios_posteriores_a_un_cursor_salen_en_orden_RF52()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        for (long seq = 1; seq <= 5; seq++)
        {
            db.ChangeLog.Add(new ChangeLogEntity { BusinessId = business.Id, Seq = seq, EntityType = ChangeEntityType.Fiado, EntityId = Guid.CreateVersion7() });
        }
        await db.SaveChangesAsync();

        var after = await db.ChangeLog
            .IgnoreQueryFilters()
            .Where(c => c.BusinessId == business.Id && c.Seq > 2)
            .OrderBy(c => c.Seq)
            .Select(c => c.Seq)
            .ToListAsync();

        Assert.Equal([3L, 4L, 5L], after);
    }

    [Fact]
    public async Task El_registro_de_cambios_no_se_edita_ni_se_borra()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        db.ChangeLog.Add(new ChangeLogEntity { BusinessId = business.Id, Seq = 1, EntityType = ChangeEntityType.Client, EntityId = Guid.CreateVersion7() });
        await db.SaveChangesAsync();

        await ThrowsSqlAsync(db, "UPDATE change_log SET seq = 2", RestrictViolation);
        await ThrowsSqlAsync(db, "DELETE FROM change_log", RestrictViolation);
    }

    // ---- contador por negocio (T062: sin seq huérfano)

    [Fact]
    public async Task El_contador_empieza_en_cero_y_entrega_1_2_3()
    {
        var (db, business) = await Setup();
        await using var _ = db;

        var first = await ChangeSequence.NextAsync(db, business.Id);
        var second = await ChangeSequence.NextAsync(db, business.Id);
        var third = await ChangeSequence.NextAsync(db, business.Id);

        Assert.Equal([1L, 2L, 3L], [first, second, third]);
        Assert.Equal(3, (await db.Businesses.AsNoTracking().SingleAsync()).LastSeq);
    }

    [Fact]
    public async Task Cada_negocio_lleva_su_propio_contador()
    {
        var (db, first) = await Setup();
        await using var _ = db;
        var second = NewBusiness("Otro negocio");
        db.Businesses.Add(second);
        await db.SaveChangesAsync();

        Assert.Equal(1, await ChangeSequence.NextAsync(db, first.Id));
        Assert.Equal(2, await ChangeSequence.NextAsync(db, first.Id));
        Assert.Equal(1, await ChangeSequence.NextAsync(db, second.Id));
    }

    [Fact]
    public async Task Un_negocio_que_no_existe_no_tiene_contador()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => ChangeSequence.NextAsync(db, Guid.CreateVersion7()));
    }

    [Fact]
    public async Task Si_la_operacion_falla_a_mitad_el_seq_no_queda_huerfano()
    {
        var (db, business) = await Setup();
        await using var _ = db;

        await using (var tx = await db.Database.BeginTransactionAsync())
        {
            var seq = await ChangeSequence.NextAsync(db, business.Id);
            Assert.Equal(1, seq);
            await tx.RollbackAsync(); // la operación falló: el contador vuelve atrás
        }

        Assert.Equal(1, await ChangeSequence.NextAsync(db, business.Id));
    }

    [Fact]
    public async Task Veinte_operaciones_a_la_vez_obtienen_seq_distintos_y_sin_huecos()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        var connection = db.Database.GetConnectionString()!;

        var seqs = await Task.WhenAll(Enumerable.Range(0, 20).Select(async _ =>
        {
            await using var ctx = PostgresFixture.NewContext(connection);
            await using var tx = await ctx.Database.BeginTransactionAsync();
            var seq = await ChangeSequence.NextAsync(ctx, business.Id);
            ctx.ChangeLog.Add(new ChangeLogEntity
            {
                BusinessId = business.Id, Seq = seq, EntityType = ChangeEntityType.Fiado, EntityId = Guid.CreateVersion7(),
            });
            await ctx.SaveChangesAsync();
            await tx.CommitAsync();
            return seq;
        }));

        Assert.Equal(Enumerable.Range(1, 20).Select(n => (long)n), seqs.OrderBy(s => s));
        Assert.Equal(20, await db.ChangeLog.IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task El_contador_no_puede_ser_negativo()
    {
        var (db, business) = await Setup();
        await using var _ = db;

        await ThrowsSqlAsync(db, $"UPDATE businesses SET last_seq = -1 WHERE id = '{business.Id}'", CheckViolation);
    }

    // ---- operaciones procesadas (RF-53)

    [Fact]
    public async Task Una_operacion_procesada_se_registra_y_se_lee()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        var opId = Guid.CreateVersion7();
        db.ProcessedOps.Add(new ProcessedOpEntity { OpId = opId, BusinessId = business.Id, Result = "applied", ProcessedAt = Now });
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.ProcessedOps.IgnoreQueryFilters().SingleAsync(o => o.OpId == opId);

        Assert.Equal("applied", read.Result);
        Assert.Equal(business.Id, read.BusinessId);
        Assert.Equal(Now, read.ProcessedAt);
    }

    [Fact]
    public async Task Una_operacion_rechazada_guarda_su_codigo_como_resultado()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        db.ProcessedOps.Add(new ProcessedOpEntity
        {
            OpId = Guid.CreateVersion7(), BusinessId = business.Id, Result = "version_conflict", ProcessedAt = Now,
        });
        await db.SaveChangesAsync();

        Assert.Equal("version_conflict", (await db.ProcessedOps.IgnoreQueryFilters().SingleAsync()).Result);
    }

    [Fact]
    public async Task Reenviar_la_misma_operacion_choca_con_la_clave_y_no_se_duplica_RF53()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        var opId = Guid.CreateVersion7();
        db.ProcessedOps.Add(new ProcessedOpEntity { OpId = opId, BusinessId = business.Id, Result = "applied", ProcessedAt = Now });
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        other.ProcessedOps.Add(new ProcessedOpEntity { OpId = opId, BusinessId = business.Id, Result = "applied", ProcessedAt = Now });

        await ThrowsPostgresAsync(() => other.SaveChangesAsync(), UniqueViolation);
    }

    [Fact]
    public async Task El_resultado_no_puede_estar_vacio_y_el_negocio_debe_existir()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        db.ProcessedOps.Add(new ProcessedOpEntity { OpId = Guid.CreateVersion7(), BusinessId = business.Id, Result = " ", ProcessedAt = Now });
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);

        db.ChangeTracker.Clear();
        db.ProcessedOps.Add(new ProcessedOpEntity { OpId = Guid.CreateVersion7(), BusinessId = Guid.CreateVersion7(), Result = "applied", ProcessedAt = Now });
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task El_resultado_de_una_operacion_procesada_no_cambia()
    {
        var (db, business) = await Setup();
        await using var _ = db;
        db.ProcessedOps.Add(new ProcessedOpEntity { OpId = Guid.CreateVersion7(), BusinessId = business.Id, Result = "applied", ProcessedAt = Now });
        await db.SaveChangesAsync();

        await ThrowsSqlAsync(db, "UPDATE processed_ops SET result = 'other'", RestrictViolation);
    }

    // ---- auditoría del administrador (RF-81, RF-82)

    private static async Task<UserEntity> AddUser(PulperiaDbContext db)
    {
        var user = new UserEntity { Id = Guid.CreateVersion7(), Email = "ana@correo.com", PasswordHash = "h", CreatedAt = Now };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user;
    }

    [Fact]
    public async Task La_auditoria_guarda_quien_restablecio_la_contrasena_y_cuando_RF81()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var user = await AddUser(db);
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(), Action = AdminAction.ResetPassword, TargetUserId = user.Id,
            PerformedBy = "operador-1", PerformedAt = Now,
        });
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.AdminAudits.SingleAsync();

        Assert.Equal(AdminAction.ResetPassword, read.Action);
        Assert.Equal(user.Id, read.TargetUserId);
        Assert.Equal("operador-1", read.PerformedBy);
        Assert.Equal(Now, read.PerformedAt);
    }

    [Fact]
    public async Task La_accion_se_guarda_con_su_id_estable()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var user = await AddUser(db);
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(), Action = AdminAction.ResetPassword, TargetUserId = user.Id,
            PerformedBy = "operador-1", PerformedAt = Now,
        });
        await db.SaveChangesAsync();

        var action = await db.Database.SqlQueryRaw<string>("SELECT action AS \"Value\" FROM admin_audit").SingleAsync();

        Assert.Equal("reset_password", action);
    }

    [Fact]
    public async Task La_auditoria_no_contiene_datos_de_ningun_negocio_RF82()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        var columns = await Columns(db, "admin_audit");

        Assert.DoesNotContain("business_id", columns);
    }

    [Fact]
    public async Task La_auditoria_exige_un_operador_y_un_usuario_existente()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var user = await AddUser(db);
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(), Action = AdminAction.ResetPassword, TargetUserId = user.Id,
            PerformedBy = "  ", PerformedAt = Now,
        });
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), CheckViolation);

        db.ChangeTracker.Clear();
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(), Action = AdminAction.ResetPassword, TargetUserId = Guid.CreateVersion7(),
            PerformedBy = "operador-1", PerformedAt = Now,
        });
        await ThrowsPostgresAsync(() => db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task La_auditoria_no_se_edita_ni_se_borra()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var user = await AddUser(db);
        db.AdminAudits.Add(new AdminAuditEntity
        {
            Id = Guid.CreateVersion7(), Action = AdminAction.ResetPassword, TargetUserId = user.Id,
            PerformedBy = "operador-1", PerformedAt = Now,
        });
        await db.SaveChangesAsync();

        await ThrowsSqlAsync(db, "UPDATE admin_audit SET performed_by = 'otro'", RestrictViolation);
        await ThrowsSqlAsync(db, "DELETE FROM admin_audit", RestrictViolation);
    }

    // ---- tipos del dominio

    [Fact]
    public void Los_ids_estables_de_tipos_de_entidad_y_acciones_se_leen_de_vuelta()
    {
        foreach (var type in Enum.GetValues<ChangeEntityType>())
        {
            Assert.Equal(type, ChangeEntityTypes.FromId(type.Id()));
        }
        foreach (var action in Enum.GetValues<AdminAction>())
        {
            Assert.Equal(action, AdminActions.FromId(action.Id()));
        }
        Assert.Throws<ArgumentException>(() => ChangeEntityTypes.FromId("user"));
        Assert.Throws<ArgumentException>(() => AdminActions.FromId("delete_account"));
    }
}
