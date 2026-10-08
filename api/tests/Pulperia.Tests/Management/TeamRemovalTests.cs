using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Accounts;
using Pulperia.Application.Management;
using Pulperia.Domain.Access;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Management;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Management;

/// <summary>T071: quitar a un usuario del negocio con protección del último dueño (RF-11, RF-71).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class TeamRemovalTests(PostgresFixture postgres)
{
    private sealed record World(AccountKit Kit, RegisteredAccount Owner, RegisteredAccount Beto, RegisteredAccount Carla);

    /// <summary>Ana es dueña; Beto y Carla son empleados de su negocio.</summary>
    private async Task<World> Setup()
    {
        var kit = await CreateAsync(postgres);
        var owner = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        var carla = await kit.RegisterAsync(Registration("carla@correo.com", businessName: "Carla"));
        kit.Db.Memberships.AddRange(
            new MembershipEntity { UserId = beto.UserId, BusinessId = owner.BusinessId, Role = Role.Employee },
            new MembershipEntity { UserId = carla.UserId, BusinessId = owner.BusinessId, Role = Role.Employee });
        await kit.Db.SaveChangesAsync();
        return new World(kit, owner, beto, carla);
    }

    [Fact]
    public async Task El_usuario_quitado_pierde_el_acceso_y_queda_constancia_de_cuando()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        w.Kit.Clock.Advance(TimeSpan.FromHours(3));

        var result = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        Assert.Null(await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Owner.BusinessId));
        var membership = await w.Kit.Db.Memberships.AsNoTracking()
            .SingleAsync(m => m.UserId == w.Beto.UserId && m.BusinessId == w.Owner.BusinessId);
        Assert.Equal((MembershipStatus.Removed, Start.UtcDateTime.AddHours(3), false),
            (membership.Status, membership.RemovedAt, membership.FinalSyncUsed));
        Assert.DoesNotContain(
            (await w.Kit.Management.ListTeamAsync(w.Owner.BusinessId, Role.Owner)).Value!, m => m.UserId == w.Beto.UserId);
    }

    [Fact]
    public async Task Quitar_a_alguien_no_toca_sus_otros_negocios_ni_a_los_demas_miembros()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);

        Assert.Equal(Role.Owner, await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Beto.BusinessId));
        Assert.Equal(Role.Employee, await w.Kit.Service.AuthorizeBusinessAsync(w.Carla.UserId, w.Owner.BusinessId));
        Assert.Equal(Role.Owner, await w.Kit.Service.AuthorizeBusinessAsync(w.Owner.UserId, w.Owner.BusinessId));
    }

    [Fact]
    public async Task No_se_puede_quitar_al_ultimo_dueno_ni_a_si_mismo_siendo_el_unico()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId);

        Assert.Equal(["team_last_owner"], result.Codes);
        Assert.Equal(Role.Owner, await w.Kit.Service.AuthorizeBusinessAsync(w.Owner.UserId, w.Owner.BusinessId));
    }

    [Fact]
    public async Task Con_dos_duenos_uno_puede_quitar_al_otro_y_el_que_queda_ya_no_puede_irse()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);

        var first = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId);
        var second = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);

        Assert.True(first.IsSuccess);
        Assert.Equal(["team_last_owner"], second.Codes);
        Assert.Null(await w.Kit.Service.AuthorizeBusinessAsync(w.Owner.UserId, w.Owner.BusinessId));
        Assert.Equal(Role.Owner, await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Owner.BusinessId));
    }

    [Fact]
    public async Task Dos_duenos_que_se_quitan_mutuamente_a_la_vez_dejan_al_menos_uno()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);
        var connectionString = w.Kit.Db.Database.GetConnectionString()!;

        async Task<bool> Remove(Guid target)
        {
            await using var db = PostgresFixture.NewContext(connectionString);
            var service = new ManagementService(new EfManagementStore(db), w.Kit.Clock);
            return (await service.RemoveAsync(w.Owner.BusinessId, Role.Owner, target)).IsSuccess;
        }

        var results = await Task.WhenAll(Remove(w.Owner.UserId), Remove(w.Beto.UserId));

        Assert.Equal(1, results.Count(ok => ok));
        var activeOwners = await w.Kit.Db.Memberships.AsNoTracking().CountAsync(
            m => m.BusinessId == w.Owner.BusinessId && m.Role == Role.Owner && m.Status == MembershipStatus.Active);
        Assert.Equal(1, activeOwners);
    }

    [Fact]
    public async Task Quitar_a_un_desconocido_o_a_alguien_ya_removido_se_rechaza()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);

        var removed = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);
        var unknown = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, Guid.CreateVersion7());
        var dana = await w.Kit.RegisterAsync(Registration("dana@correo.com", businessName: "Dana"));
        var foreign = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, dana.UserId);

        Assert.Equal(["team_member_not_active"], removed.Codes);
        Assert.Equal(["team_member_not_found"], unknown.Codes);
        Assert.Equal(["team_member_not_found"], foreign.Codes);
    }

    [Fact]
    public async Task Un_empleado_no_puede_quitar_a_nadie()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Employee, w.Carla.UserId);

        Assert.Equal(["forbidden"], result.Codes);
        Assert.Equal(Role.Employee, await w.Kit.Service.AuthorizeBusinessAsync(w.Carla.UserId, w.Owner.BusinessId));
    }

    [Fact]
    public async Task Quien_fue_quitado_puede_volver_si_lo_invitan_de_nuevo()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.Management.RemoveAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);
        var invitation = (await w.Kit.Management.InviteAsync(
            w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "beto@correo.com")).Value!;

        Assert.True((await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, invitation.Id)).IsSuccess);

        Assert.Equal(Role.Employee, await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Owner.BusinessId));
    }

    // ---- HTTP

    [Fact]
    public async Task Por_HTTP_quitar_responde_204_y_el_quitado_ya_no_ve_ese_negocio()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        async Task<(string Token, Guid UserId, Guid BusinessId)> Account(string email)
        {
            var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
            {
                email, password = "contrasena1", businessName = email, amountMode = "two_decimals", quantityMode = "fractional",
            }));
            var login = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
            return (login.GetProperty("accessToken").GetString()!, register.GetProperty("userId").GetGuid(),
                register.GetProperty("businessId").GetGuid());
        }
        var ana = await Account("ana@correo.com");
        var beto = await Account("beto@correo.com");
        host.Db.Memberships.Add(new MembershipEntity { UserId = beto.UserId, BusinessId = ana.BusinessId, Role = Role.Employee });
        await host.Db.SaveChangesAsync();

        var lastOwner = await host.DeleteAsync($"/api/business/team/{ana.UserId}", ana.Token, ana.BusinessId);
        var asEmployee = await host.DeleteAsync($"/api/business/team/{ana.UserId}", beto.Token, ana.BusinessId);
        var remove = await host.DeleteAsync($"/api/business/team/{beto.UserId}", ana.Token, ana.BusinessId);
        var again = await host.DeleteAsync($"/api/business/team/{beto.UserId}", ana.Token, ana.BusinessId);
        var betoBusinesses = await ApiTestHost.JsonOf(await host.GetAsync("/api/businesses", beto.Token));
        var betoAccess = await host.GetAsync("/api/business", beto.Token, ana.BusinessId);

        Assert.Equal(HttpStatusCode.Conflict, lastOwner.StatusCode);
        Assert.Equal("team_last_owner", (await ApiTestHost.JsonOf(lastOwner)).GetProperty("code").GetString());
        Assert.Equal(HttpStatusCode.Forbidden, asEmployee.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, remove.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(1, betoBusinesses.GetArrayLength());
        Assert.Equal(HttpStatusCode.Forbidden, betoAccess.StatusCode);
    }
}
