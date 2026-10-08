using Microsoft.EntityFrameworkCore;
using Npgsql;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Domain.Invitations;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Persistence;

/// <summary>
/// T051: usuarios, negocios, pertenencias e invitaciones contra un PostgreSQL real (D-25).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class IdentityPersistenceTests(PostgresFixture postgres)
{
    private static readonly DateTime Now = new(2026, 10, 8, 12, 0, 0, DateTimeKind.Utc);

    private static UserEntity User(string email = "ana@correo.com") => new()
    {
        Id = Guid.CreateVersion7(),
        Email = email,
        PasswordHash = "hash-de-prueba",
        CreatedAt = Now,
    };

    private static BusinessEntity Business(string name = "Pulpería Ana") => new()
    {
        Id = Guid.CreateVersion7(),
        Name = name,
        AmountMode = AmountMode.TwoDecimals,
        QuantityMode = QuantityMode.Fractional,
        CreatedAt = Now,
    };

    private static async Task<T> ThrowsPostgresAsync<T>(Func<Task> action, string sqlState)
        where T : Exception
    {
        var ex = await Assert.ThrowsAsync<T>(action);
        var pg = Assert.IsType<PostgresException>(ex.InnerException);
        Assert.Equal(sqlState, pg.SqlState);
        return ex;
    }

    private const string CheckViolation = "23514";
    private const string UniqueViolation = "23505";
    private const string ForeignKeyViolation = "23503";

    // ---- migración y nombres

    [Fact]
    public async Task La_migracion_crea_las_cuatro_tablas_en_snake_case()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        var tables = await db.Database
            .SqlQueryRaw<string>("SELECT table_name AS \"Value\" FROM information_schema.tables WHERE table_schema = 'public'")
            .ToListAsync();

        Assert.Contains("users", tables);
        Assert.Contains("businesses", tables);
        Assert.Contains("memberships", tables);
        Assert.Contains("invitations", tables);
    }

    [Fact]
    public async Task El_modelo_no_tiene_cambios_sin_migrar()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        // Si falla: se cambió una entidad sin generar su migración (dotnet ef migrations add).
        Assert.False(db.Database.HasPendingModelChanges());
    }

    [Fact]
    public async Task Las_columnas_usan_snake_case()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        var columns = await db.Database
            .SqlQueryRaw<string>("SELECT column_name AS \"Value\" FROM information_schema.columns WHERE table_name = 'memberships'")
            .ToListAsync();

        Assert.Equivalent(
            new[] { "user_id", "business_id", "role", "status", "removed_at", "final_sync_used" },
            columns);
    }

    // ---- usuarios (RF-1, RF-2)

    [Fact]
    public async Task Un_usuario_se_crea_y_se_lee()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var user = User();
        db.Users.Add(user);
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Users.SingleAsync(u => u.Id == user.Id);

        Assert.Equal("ana@correo.com", read.Email);
        Assert.Equal("hash-de-prueba", read.PasswordHash);
        Assert.Equal(Now, read.CreatedAt);
        Assert.Equal(DateTimeKind.Utc, read.CreatedAt.Kind);
    }

    [Fact]
    public async Task El_correo_es_unico()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        db.Users.Add(User("ana@correo.com"));
        await db.SaveChangesAsync();
        db.Users.Add(User("ana@correo.com"));

        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), UniqueViolation);
    }

    [Fact]
    public async Task El_correo_debe_guardarse_normalizado_asi_no_hay_dos_cuentas_por_mayusculas()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        db.Users.Add(User("Ana@Correo.com"));

        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task El_correo_no_puede_estar_vacio_ni_llevar_espacios_exteriores()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        db.Users.Add(User(" ana@correo.com"));

        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), CheckViolation);
    }

    // ---- negocios (RF-1, RF-7, RF-78)

    [Fact]
    public async Task Un_negocio_se_crea_y_se_lee_con_sus_modos_y_contador_en_cero()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var business = Business();
        db.Businesses.Add(business);
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Businesses.SingleAsync(b => b.Id == business.Id);

        Assert.Equal("Pulpería Ana", read.Name);
        Assert.Equal(AmountMode.TwoDecimals, read.AmountMode);
        Assert.Equal(QuantityMode.Fractional, read.QuantityMode);
        Assert.Equal(0, read.LastSeq);
        Assert.Equal(Now, read.CreatedAt);
    }

    [Fact]
    public async Task Los_modos_se_guardan_con_los_ids_estables_de_los_vectores()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var business = Business();
        business.AmountMode = AmountMode.Integer;
        business.QuantityMode = QuantityMode.Integer;
        db.Businesses.Add(business);
        await db.SaveChangesAsync();

        var stored = await db.Database
            .SqlQueryRaw<string>("SELECT amount_mode || '/' || quantity_mode AS \"Value\" FROM businesses")
            .SingleAsync();

        Assert.Equal("integer/integer", stored);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task El_nombre_del_negocio_es_obligatorio_RF78(string name)
    {
        await using var db = await postgres.CreateDatabaseAsync();
        db.Businesses.Add(Business(name));

        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Un_modo_fuera_de_la_lista_se_rechaza_en_la_base()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        var id = Guid.CreateVersion7();

        var ex = await Assert.ThrowsAsync<PostgresException>(() => db.Database.ExecuteSqlRawAsync(
            "INSERT INTO businesses (id, name, amount_mode, quantity_mode, last_seq, created_at) " +
            $"VALUES ('{id}', 'X', 'decimal', 'integer', 0, now())"));

        Assert.Equal(CheckViolation, ex.SqlState);
    }

    // ---- pertenencias (RF-5, RF-6, RF-11, RF-12)

    private async Task<(PulperiaDbContext Db, UserEntity User, BusinessEntity Business)> WithUserAndBusiness()
    {
        var db = await postgres.CreateDatabaseAsync();
        var user = User();
        var business = Business();
        db.Users.Add(user);
        db.Businesses.Add(business);
        await db.SaveChangesAsync();
        return (db, user, business);
    }

    [Fact]
    public async Task Una_pertenencia_se_crea_y_se_lee_con_su_rol_y_estado()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        db.Memberships.Add(new MembershipEntity
        {
            UserId = user.Id,
            BusinessId = business.Id,
            Role = Role.Owner,
            Status = MembershipStatus.Active,
        });
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Memberships.SingleAsync();

        Assert.Equal(Role.Owner, read.Role);
        Assert.Equal(MembershipStatus.Active, read.Status);
        Assert.Null(read.RemovedAt);
        Assert.False(read.FinalSyncUsed);
    }

    [Fact]
    public async Task Una_pertenencia_removida_guarda_cuando_y_si_ya_uso_su_ultimo_lote()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        db.Memberships.Add(new MembershipEntity
        {
            UserId = user.Id,
            BusinessId = business.Id,
            Role = Role.Employee,
            Status = MembershipStatus.Removed,
            RemovedAt = Now,
            FinalSyncUsed = true,
        });
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Memberships.SingleAsync();

        Assert.Equal(MembershipStatus.Removed, read.Status);
        Assert.Equal(Now, read.RemovedAt);
        Assert.True(read.FinalSyncUsed);
    }

    [Fact]
    public async Task Un_usuario_pertenece_a_varios_negocios_con_roles_distintos_RF5()
    {
        var (db, user, first) = await WithUserAndBusiness();
        await using var _ = db;
        var second = Business("Otra pulpería");
        db.Businesses.Add(second);
        db.Memberships.AddRange(
            new MembershipEntity { UserId = user.Id, BusinessId = first.Id, Role = Role.Owner },
            new MembershipEntity { UserId = user.Id, BusinessId = second.Id, Role = Role.Employee });
        await db.SaveChangesAsync();

        var roles = await db.Memberships
            .Where(m => m.UserId == user.Id)
            .Select(m => m.Role)
            .ToListAsync();

        Assert.Equivalent(new[] { Role.Owner, Role.Employee }, roles);
    }

    [Fact]
    public async Task Una_persona_solo_tiene_una_pertenencia_por_negocio()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        db.Memberships.Add(new MembershipEntity { UserId = user.Id, BusinessId = business.Id, Role = Role.Owner });
        await db.SaveChangesAsync();
        // Otro contexto: en el mismo, EF ya rechaza registrar dos veces la misma clave.
        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        other.Memberships.Add(new MembershipEntity { UserId = user.Id, BusinessId = business.Id, Role = Role.Employee });

        await ThrowsPostgresAsync<DbUpdateException>(() => other.SaveChangesAsync(), UniqueViolation);
    }

    [Fact]
    public async Task Una_pertenencia_exige_que_existan_el_usuario_y_el_negocio()
    {
        await using var db = await postgres.CreateDatabaseAsync();
        db.Memberships.Add(new MembershipEntity
        {
            UserId = Guid.CreateVersion7(),
            BusinessId = Guid.CreateVersion7(),
            Role = Role.Owner,
        });

        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task Un_rol_o_estado_fuera_de_la_lista_se_rechaza_en_la_base()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;

        var ex = await Assert.ThrowsAsync<PostgresException>(() => db.Database.ExecuteSqlRawAsync(
            "INSERT INTO memberships (user_id, business_id, role, status, final_sync_used) " +
            $"VALUES ('{user.Id}', '{business.Id}', 'admin', 'active', false)"));

        Assert.Equal(CheckViolation, ex.SqlState);
    }

    [Fact]
    public async Task Una_pertenencia_removida_debe_tener_fecha_de_baja()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        db.Memberships.Add(new MembershipEntity
        {
            UserId = user.Id,
            BusinessId = business.Id,
            Role = Role.Employee,
            Status = MembershipStatus.Removed,
            RemovedAt = null,
        });

        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), CheckViolation);
    }

    // ---- invitaciones (RF-10, RF-67, RF-68, RF-69)

    private static InvitationEntity Invitation(Guid businessId, Guid createdBy, string email = "beto@correo.com") => new()
    {
        Id = Guid.CreateVersion7(),
        BusinessId = businessId,
        Email = email,
        Code = Pulperia.Domain.Invitations.InvitationCodes.Generate(),
        Status = InvitationStatus.Pending,
        CreatedBy = createdBy,
        CreatedAt = Now,
    };

    [Fact]
    public async Task Una_invitacion_se_crea_y_se_lee_pendiente()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        var invitation = Invitation(business.Id, user.Id);
        db.Invitations.Add(invitation);
        await db.SaveChangesAsync();

        await using var other = PostgresFixture.NewContext(db.Database.GetConnectionString()!);
        var read = await other.Invitations.SingleAsync(i => i.Id == invitation.Id);

        Assert.Equal("beto@correo.com", read.Email);
        Assert.Equal(InvitationStatus.Pending, read.Status);
        Assert.Equal(business.Id, read.BusinessId);
        Assert.Equal(user.Id, read.CreatedBy);
        Assert.Equal(Now, read.CreatedAt);
    }

    [Theory]
    [InlineData(InvitationStatus.Accepted, "accepted")]
    [InlineData(InvitationStatus.Rejected, "rejected")]
    [InlineData(InvitationStatus.Cancelled, "cancelled")]
    public async Task Los_estados_se_guardan_con_ids_estables(InvitationStatus status, string stored)
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        var invitation = Invitation(business.Id, user.Id);
        invitation.Status = status;
        db.Invitations.Add(invitation);
        await db.SaveChangesAsync();

        var value = await db.Database
            .SqlQueryRaw<string>("SELECT status AS \"Value\" FROM invitations")
            .SingleAsync();

        Assert.Equal(stored, value);
    }

    [Fact]
    public async Task La_invitacion_no_caduca_no_hay_fecha_de_vencimiento_RF10()
    {
        await using var db = await postgres.CreateDatabaseAsync();

        var columns = await db.Database
            .SqlQueryRaw<string>("SELECT column_name AS \"Value\" FROM information_schema.columns WHERE table_name = 'invitations'")
            .ToListAsync();

        Assert.DoesNotContain(columns, c => c.Contains("expire", StringComparison.OrdinalIgnoreCase));
        Assert.Equivalent(
            new[] { "id", "business_id", "email", "status", "created_by", "created_at" },
            columns);
    }

    [Fact]
    public async Task Una_invitacion_exige_negocio_y_creador_existentes()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        db.Invitations.Add(Invitation(Guid.CreateVersion7(), user.Id));
        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), ForeignKeyViolation);

        db.ChangeTracker.Clear();
        db.Invitations.Add(Invitation(business.Id, Guid.CreateVersion7()));
        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), ForeignKeyViolation);
    }

    [Fact]
    public async Task El_correo_de_la_invitacion_debe_estar_normalizado()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        db.Invitations.Add(Invitation(business.Id, user.Id, "Beto@Correo.com"));

        await ThrowsPostgresAsync<DbUpdateException>(() => db.SaveChangesAsync(), CheckViolation);
    }

    [Fact]
    public async Task Se_pueden_buscar_las_invitaciones_pendientes_de_un_correo_RF67()
    {
        var (db, user, business) = await WithUserAndBusiness();
        await using var _ = db;
        var other = Business("Otra pulpería");
        db.Businesses.Add(other);
        var pending = Invitation(business.Id, user.Id);
        var cancelled = Invitation(other.Id, user.Id);
        cancelled.Status = InvitationStatus.Cancelled;
        db.Invitations.AddRange(pending, cancelled, Invitation(business.Id, user.Id, "ana@correo.com"));
        await db.SaveChangesAsync();

        var found = await db.Invitations
            .Where(i => i.Email == "beto@correo.com" && i.Status == InvitationStatus.Pending)
            .ToListAsync();

        Assert.Equal([pending.Id], found.Select(i => i.Id));
    }

    // ---- mapeo explícito con el dominio

    [Fact]
    public void Una_invitacion_pasa_del_dominio_a_la_base_y_vuelve_igual()
    {
        var domain = new Invitation(Guid.CreateVersion7(), Guid.CreateVersion7(), "beto@correo.com", InvitationStatus.Accepted, "ABCDEFGH");
        var createdBy = Guid.CreateVersion7();

        var entity = InvitationEntity.FromDomain(domain, createdBy, Now);

        Assert.Equal(createdBy, entity.CreatedBy);
        Assert.Equal(Now, entity.CreatedAt);
        Assert.Equal(domain, entity.ToDomain());
    }

    [Fact]
    public void Una_pertenencia_pasa_del_dominio_a_la_base_y_vuelve_igual()
    {
        var businessId = Guid.CreateVersion7();
        var domain = new Member(Guid.CreateVersion7(), Role.Employee, MembershipStatus.Removed);

        var entity = MembershipEntity.FromDomain(domain, businessId, Now);

        Assert.Equal(businessId, entity.BusinessId);
        Assert.Equal(Now, entity.RemovedAt);
        Assert.Equal(domain, entity.ToDomain());
    }

    [Fact]
    public void Una_pertenencia_activa_no_lleva_fecha_de_baja()
    {
        var entity = MembershipEntity.FromDomain(new Member(Guid.CreateVersion7(), Role.Owner), Guid.CreateVersion7(), Now);

        Assert.Null(entity.RemovedAt);
    }
}
