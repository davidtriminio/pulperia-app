using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Invitations;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Infrastructure.Persistence;

/// <summary>
/// Base de datos del servidor (PostgreSQL). Las clases de persistencia viven aquí, separadas
/// de los <c>record</c> del dominio, que no conoce EF (D-25). Todo registro de negocio lleva
/// <c>business_id</c> (principio 6).
/// </summary>
public sealed class PulperiaDbContext(DbContextOptions<PulperiaDbContext> options) : DbContext(options)
{
    public DbSet<UserEntity> Users => Set<UserEntity>();

    public DbSet<BusinessEntity> Businesses => Set<BusinessEntity>();

    public DbSet<MembershipEntity> Memberships => Set<MembershipEntity>();

    public DbSet<InvitationEntity> Invitations => Set<InvitationEntity>();

    public DbSet<ClientEntity> Clients => Set<ClientEntity>();

    public DbSet<ProductEntity> Products => Set<ProductEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ConfigureUsers(modelBuilder);
        ConfigureBusinesses(modelBuilder);
        ConfigureMemberships(modelBuilder);
        ConfigureInvitations(modelBuilder);
        ConfigureClients(modelBuilder);
        ConfigureProducts(modelBuilder);

        SnakeCase.Apply(modelBuilder);
    }

    private const string NormalizedEmail = "{0} = lower(btrim({0})) AND btrim({0}) <> ''";

    private static void ConfigureUsers(ModelBuilder modelBuilder) =>
        modelBuilder.Entity<UserEntity>(e =>
        {
            e.ToTable("users", t =>
                t.HasCheckConstraint("ck_users_email_normalized", string.Format(NormalizedEmail, "email")));
            e.HasKey(x => x.Id);
            e.Property(x => x.Email).IsRequired();
            e.Property(x => x.PasswordHash).IsRequired();
            e.HasIndex(x => x.Email).IsUnique();
        });

    private static void ConfigureBusinesses(ModelBuilder modelBuilder) =>
        modelBuilder.Entity<BusinessEntity>(e =>
        {
            e.ToTable("businesses", t =>
            {
                t.HasCheckConstraint("ck_businesses_name_required", "btrim(name) <> ''");
                t.HasCheckConstraint("ck_businesses_amount_mode", "amount_mode IN ('integer', 'two_decimals')");
                t.HasCheckConstraint("ck_businesses_quantity_mode", "quantity_mode IN ('integer', 'fractional')");
                t.HasCheckConstraint("ck_businesses_last_seq", "last_seq >= 0");
            });
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).IsRequired();
            e.Property(x => x.AmountMode).HasConversion(m => m.Id(), id => AmountModes.FromId(id));
            e.Property(x => x.QuantityMode).HasConversion(m => m.Id(), id => QuantityModes.FromId(id));
            e.Property(x => x.LastSeq).HasDefaultValue(0L);
        });

    private static void ConfigureMemberships(ModelBuilder modelBuilder) =>
        modelBuilder.Entity<MembershipEntity>(e =>
        {
            e.ToTable("memberships", t =>
            {
                t.HasCheckConstraint("ck_memberships_role", "role IN ('owner', 'employee')");
                t.HasCheckConstraint("ck_memberships_status", "status IN ('active', 'removed')");
                // Quitar a alguien deja constancia de cuándo (RF-11, RF-12).
                t.HasCheckConstraint("ck_memberships_removed_at", "status <> 'removed' OR removed_at IS NOT NULL");
            });
            e.HasKey(x => new { x.UserId, x.BusinessId });
            e.Property(x => x.Role).HasConversion(r => r.Id(), id => Roles.FromId(id));
            e.Property(x => x.Status).HasConversion(s => MembershipStatusId(s), id => MembershipStatusFromId(id));
            e.HasOne<UserEntity>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<BusinessEntity>().WithMany().HasForeignKey(x => x.BusinessId).OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(x => x.BusinessId);
        });

    private static void ConfigureInvitations(ModelBuilder modelBuilder) =>
        modelBuilder.Entity<InvitationEntity>(e =>
        {
            e.ToTable("invitations", t =>
            {
                t.HasCheckConstraint("ck_invitations_email_normalized", string.Format(NormalizedEmail, "email"));
                t.HasCheckConstraint(
                    "ck_invitations_status",
                    "status IN ('pending', 'accepted', 'rejected', 'cancelled')");
            });
            e.HasKey(x => x.Id);
            e.Property(x => x.Email).IsRequired();
            e.Property(x => x.Status).HasConversion(s => s.Id(), id => InvitationStatuses.FromId(id));
            e.HasOne<BusinessEntity>().WithMany().HasForeignKey(x => x.BusinessId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<UserEntity>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.Restrict);
            // Las invitaciones pendientes de un correo se buscan al iniciar sesión (RF-67).
            e.HasIndex(x => new { x.Email, x.Status });
            e.HasIndex(x => x.BusinessId);
        });

    private static void ConfigureClients(ModelBuilder modelBuilder) =>
        modelBuilder.Entity<ClientEntity>(e =>
        {
            e.ToTable("clients", t =>
            {
                t.HasCheckConstraint("ck_clients_name_required", "btrim(name) <> ''");
                t.HasCheckConstraint("ck_clients_note_length", "note IS NULL OR char_length(note) <= 300");
                t.HasCheckConstraint("ck_clients_phone_format", "phone IS NULL OR phone ~ '^[2389][0-9]{7}$'");
                t.HasCheckConstraint("ck_clients_version", "version >= 1");
            });
            e.HasKey(x => x.Id);
            // El par (id, negocio) lo referencian fiados y abonos: así un fiado no puede
            // apuntar a un cliente de otro negocio (RNF-6).
            e.HasAlternateKey(x => new { x.Id, x.BusinessId });
            e.Property(x => x.Name).IsRequired();
            e.Property(x => x.CharacterId).IsRequired();
            e.Property(x => x.SkinId).IsRequired();
            e.Property(x => x.BackgroundId).IsRequired();
            e.HasOne<BusinessEntity>().WithMany().HasForeignKey(x => x.BusinessId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<UserEntity>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(x => x.BusinessId);
        });

    private static void ConfigureProducts(ModelBuilder modelBuilder) =>
        modelBuilder.Entity<ProductEntity>(e =>
        {
            e.ToTable("products", t =>
            {
                t.HasCheckConstraint("ck_products_name_required", "btrim(name) <> ''");
                t.HasCheckConstraint("ck_products_price", "price > 0");
                t.HasCheckConstraint(
                    "ck_products_unit",
                    "unit IN ('unit', 'pound', 'ounce', 'kilo', 'dozen', 'liter', 'gallon', 'box', 'bag', 'pack')");
                t.HasCheckConstraint("ck_products_previous_price", "previous_price IS NULL OR previous_price > 0");
                // El precio anterior y la fecha del cambio van juntos o ninguno (D-24).
                t.HasCheckConstraint(
                    "ck_products_price_history_pair",
                    "(previous_price IS NULL) = (price_changed_at IS NULL)");
                t.HasCheckConstraint("ck_products_version", "version >= 1");
            });
            e.HasKey(x => x.Id);
            e.HasAlternateKey(x => new { x.Id, x.BusinessId });
            e.Property(x => x.Name).IsRequired();
            e.Property(x => x.Unit).HasConversion(u => u.Id(), id => SaleUnits.TryFromId(id)!.Value);
            e.HasOne<BusinessEntity>().WithMany().HasForeignKey(x => x.BusinessId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<UserEntity>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(x => x.BusinessId);
        });

    private static string MembershipStatusId(MembershipStatus status) => status switch
    {
        MembershipStatus.Active => "active",
        MembershipStatus.Removed => "removed",
        _ => throw new ArgumentOutOfRangeException(nameof(status)),
    };

    private static MembershipStatus MembershipStatusFromId(string id) => id switch
    {
        "active" => MembershipStatus.Active,
        "removed" => MembershipStatus.Removed,
        _ => throw new ArgumentException($"Estado de pertenencia desconocido: {id}", nameof(id)),
    };
}
