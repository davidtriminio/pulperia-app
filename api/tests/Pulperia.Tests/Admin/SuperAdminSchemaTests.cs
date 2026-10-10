using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Admin;
using Pulperia.Domain.Business;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T186: la migración <c>SuperAdministrador</c> y lo que la base garantiza por sí misma: estado del
/// negocio, auditoría solo de inserción y el último super administrador (RF-95, RF-98, RF-101, D-29, D-30).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SuperAdminSchemaTests(PostgresFixture postgres)
{
    private async Task<(AccountKit Kit, Guid AnaId, Guid AnaBusiness, Guid BetoId)> Setup()
    {
        var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        return (kit, ana.UserId, ana.BusinessId, beto.UserId);
    }

    private static AdminAuditEntity Audit(
        AdminAction action, Guid? user = null, Guid? business = null, string? detail = null) => new()
    {
        Id = Guid.CreateVersion7(), Action = action, TargetUserId = user, TargetBusinessId = business,
        Detail = detail, PerformedBy = "root@servidor", PerformedAt = Start.UtcDateTime,
    };

    // ---- estado del negocio y de la cuenta

    [Fact]
    public async Task El_negocio_de_un_registro_nace_pendiente_y_la_cuenta_sin_marca_ni_suspension()
    {
        var (kit, ana, business, _) = await Setup();
        await using var _k = kit;

        var stored = await kit.Db.Businesses.AsNoTracking().SingleAsync(b => b.Id == business);
        var user = await kit.Db.Users.AsNoTracking().SingleAsync(u => u.Id == ana);

        Assert.Equal((BusinessStatus.Pending, null), (stored.Status, stored.StatusReason));
        Assert.Equal((false, null, null), (user.IsSuperAdmin, user.SuspendedAt, user.SuspensionReason));
    }

    [Fact]
    public async Task La_base_rechaza_un_estado_de_negocio_desconocido()
    {
        var (kit, _, business, _) = await Setup();
        await using var _k = kit;

        await Assert.ThrowsAnyAsync<Exception>(() => kit.Db.Database.ExecuteSqlAsync(
            $"UPDATE businesses SET status = 'archivado' WHERE id = {business}"));
    }

    [Fact]
    public async Task El_estado_del_negocio_se_guarda_con_su_motivo()
    {
        var (kit, _, business, _) = await Setup();
        await using var _k = kit;

        await kit.Db.Businesses.Where(b => b.Id == business).ExecuteUpdateAsync(s => s
            .SetProperty(b => b.Status, BusinessStatus.Suspended)
            .SetProperty(b => b.StatusReason, "Falta de pago"));

        var stored = await kit.Db.Businesses.AsNoTracking().SingleAsync(b => b.Id == business);
        Assert.Equal((BusinessStatus.Suspended, "Falta de pago"), (stored.Status, stored.StatusReason));
    }

    // ---- auditoría ampliada y de solo inserción

    [Theory]
    [InlineData(AdminAction.GrantSuperAdmin, false)]
    [InlineData(AdminAction.RevokeSuperAdmin, false)]
    [InlineData(AdminAction.ReactivateAccount, false)]
    [InlineData(AdminAction.SuspendAccount, true)]
    public async Task La_auditoria_acepta_las_acciones_sobre_una_cuenta(AdminAction action, bool needsReason)
    {
        var (kit, ana, _, _) = await Setup();
        await using var _k = kit;

        kit.Db.AdminAudits.Add(Audit(action, user: ana, detail: needsReason ? "Abuso" : null));
        await kit.Db.SaveChangesAsync();

        Assert.Equal(1, await kit.Db.AdminAudits.CountAsync(a => a.TargetUserId == ana));
    }

    [Theory]
    [InlineData(AdminAction.ActivateBusiness, false)]
    [InlineData(AdminAction.ReactivateBusiness, false)]
    [InlineData(AdminAction.SuspendBusiness, true)]
    public async Task La_auditoria_acepta_las_acciones_sobre_un_negocio_sin_cuenta_destino(
        AdminAction action, bool needsReason)
    {
        var (kit, _, business, _) = await Setup();
        await using var _k = kit;

        kit.Db.AdminAudits.Add(Audit(action, business: business, detail: needsReason ? "Falta de pago" : null));
        await kit.Db.SaveChangesAsync();

        var stored = await kit.Db.AdminAudits.AsNoTracking().SingleAsync();
        Assert.Equal((null, business), (stored.TargetUserId, stored.TargetBusinessId));
    }

    [Fact]
    public async Task Una_suspension_sin_motivo_se_rechaza()
    {
        var (kit, _, business, _) = await Setup();
        await using var _k = kit;
        kit.Db.AdminAudits.Add(Audit(AdminAction.SuspendBusiness, business: business, detail: "  "));

        await Assert.ThrowsAnyAsync<DbUpdateException>(() => kit.Db.SaveChangesAsync());
    }

    [Fact]
    public async Task Una_accion_sin_cuenta_ni_negocio_destino_se_rechaza()
    {
        var (kit, _, _, _) = await Setup();
        await using var _k = kit;
        kit.Db.AdminAudits.Add(Audit(AdminAction.ResetPassword));

        await Assert.ThrowsAnyAsync<DbUpdateException>(() => kit.Db.SaveChangesAsync());
    }

    [Fact]
    public async Task La_auditoria_no_se_edita_ni_se_borra()
    {
        var (kit, ana, business, _) = await Setup();
        await using var _k = kit;
        kit.Db.AdminAudits.Add(Audit(AdminAction.SuspendBusiness, business: business, detail: "Falta de pago"));
        kit.Db.AdminAudits.Add(Audit(AdminAction.GrantSuperAdmin, user: ana));
        await kit.Db.SaveChangesAsync();

        await Assert.ThrowsAnyAsync<Exception>(() => kit.Db.Database.ExecuteSqlAsync(
            $"UPDATE admin_audit SET detail = 'otro motivo'"));
        await Assert.ThrowsAnyAsync<Exception>(() => kit.Db.Database.ExecuteSqlAsync(
            $"DELETE FROM admin_audit"));
        Assert.Equal(2, await kit.Db.AdminAudits.CountAsync());
    }

    // ---- el último super administrador

    [Fact]
    public async Task La_base_no_deja_retirar_la_marca_al_ultimo_super_administrador()
    {
        var (kit, ana, _, beto) = await Setup();
        await using var _k = kit;
        await kit.Db.Users.Where(u => u.Id == ana || u.Id == beto)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));

        // Con dos, se puede retirar a uno...
        await kit.Db.Users.Where(u => u.Id == beto).ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, false));

        // ...pero no al único que queda.
        var ex = await Assert.ThrowsAnyAsync<Exception>(() => kit.Db.Users.Where(u => u.Id == ana)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, false)));
        Assert.Contains("last_super_admin", ex.ToString());
        Assert.True((await kit.Db.Users.AsNoTracking().SingleAsync(u => u.Id == ana)).IsSuperAdmin);
    }

    [Fact]
    public async Task Retirar_la_marca_a_quien_no_la_tiene_no_estorba()
    {
        var (kit, ana, _, beto) = await Setup();
        await using var _k = kit;
        await kit.Db.Users.Where(u => u.Id == ana).ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));

        await kit.Db.Users.Where(u => u.Id == beto).ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, false));

        Assert.True((await kit.Db.Users.AsNoTracking().SingleAsync(u => u.Id == ana)).IsSuperAdmin);
    }
}
