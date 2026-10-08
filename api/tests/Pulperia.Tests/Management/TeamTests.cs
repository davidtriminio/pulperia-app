using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Management;

/// <summary>T070: listar el equipo y promover a dueño (RF-70).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class TeamTests(PostgresFixture postgres)
{
    private sealed record World(AccountKit Kit, RegisteredAccount Owner, RegisteredAccount Beto, RegisteredAccount Carla);

    /// <summary>Ana es dueña; Beto es empleado; Carla fue removida.</summary>
    private async Task<World> Setup()
    {
        var kit = await CreateAsync(postgres);
        var owner = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        var carla = await kit.RegisterAsync(Registration("carla@correo.com", businessName: "Carla"));
        kit.Db.Memberships.AddRange(
            new MembershipEntity { UserId = beto.UserId, BusinessId = owner.BusinessId, Role = Role.Employee },
            new MembershipEntity
            {
                UserId = carla.UserId, BusinessId = owner.BusinessId, Role = Role.Employee,
                Status = MembershipStatus.Removed, RemovedAt = Start.UtcDateTime,
            });
        await kit.Db.SaveChangesAsync();
        return new World(kit, owner, beto, carla);
    }

    // ---- listar

    [Fact]
    public async Task El_dueno_ve_el_equipo_activo_con_correo_y_rol_duenos_primero()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.ListTeamAsync(w.Owner.BusinessId, Role.Owner);

        Assert.True(result.IsSuccess);
        Assert.Equal(
            [("ana@correo.com", Role.Owner), ("beto@correo.com", Role.Employee)],
            result.Value!.Select(m => (m.Email, m.Role)));
        Assert.Equal([w.Owner.UserId, w.Beto.UserId], result.Value.Select(m => m.UserId));
    }

    [Fact]
    public async Task Un_empleado_no_puede_ver_el_equipo()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.ListTeamAsync(w.Owner.BusinessId, Role.Employee);

        Assert.Equal(["forbidden"], result.Codes);
    }

    [Fact]
    public async Task El_equipo_no_incluye_miembros_de_otros_negocios()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.ListTeamAsync(w.Beto.BusinessId, Role.Owner);

        Assert.Equal(["beto@correo.com"], result.Value!.Select(m => m.Email));
    }

    // ---- promover

    [Fact]
    public async Task Promover_a_un_empleado_le_da_todos_los_permisos_de_dueno()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        Assert.Equal(Role.Employee, await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Owner.BusinessId));

        var result = await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        Assert.Equal((w.Beto.UserId, Role.Owner), (result.Value!.UserId, result.Value.Role));
        var role = await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Owner.BusinessId);
        Assert.Equal(Role.Owner, role);
        foreach (var permission in Enum.GetValues<Permission>())
        {
            Assert.True(RolePermissions.Can(role!.Value, permission));
        }
        // y lo demuestra en la práctica: ya puede invitar
        Assert.True((await w.Kit.Management.InviteAsync(
            w.Owner.BusinessId, role.Value, w.Beto.UserId, "nuevo@correo.com")).IsSuccess);
    }

    [Fact]
    public async Task Promover_no_cambia_a_nadie_mas()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Owner, w.Beto.UserId);

        var carla = await w.Kit.Db.Memberships.AsNoTracking()
            .SingleAsync(m => m.UserId == w.Carla.UserId && m.BusinessId == w.Owner.BusinessId);
        Assert.Equal((Role.Employee, MembershipStatus.Removed), (carla.Role, carla.Status));
        var betoOwn = await w.Kit.Db.Memberships.AsNoTracking()
            .SingleAsync(m => m.UserId == w.Beto.UserId && m.BusinessId == w.Beto.BusinessId);
        Assert.Equal(Role.Owner, betoOwn.Role);
    }

    [Fact]
    public async Task Promover_a_un_dueno_a_un_removido_o_a_un_desconocido_se_rechaza()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var owner = await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId);
        var removed = await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Owner, w.Carla.UserId);
        var unknown = await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Owner, Guid.CreateVersion7());

        Assert.Equal(["team_already_owner"], owner.Codes);
        Assert.Equal(["team_member_not_active"], removed.Codes);
        Assert.Equal(["team_member_not_found"], unknown.Codes);
    }

    [Fact]
    public async Task Un_empleado_no_puede_promover_ni_siquiera_a_si_mismo()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.PromoteAsync(w.Owner.BusinessId, Role.Employee, w.Beto.UserId);

        Assert.Equal(["forbidden"], result.Codes);
        Assert.Equal(Role.Employee, await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Owner.BusinessId));
    }

    // ---- HTTP

    [Fact]
    public async Task Por_HTTP_listar_y_promover()
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

        var team = await ApiTestHost.JsonOf(await host.GetAsync("/api/business/team", ana.Token, ana.BusinessId));
        var asEmployee = await host.GetAsync("/api/business/team", beto.Token, ana.BusinessId);
        var promote = await host.PostAsync($"/api/business/team/{beto.UserId}/promote", null, ana.Token, ana.BusinessId);
        var again = await host.PostAsync($"/api/business/team/{beto.UserId}/promote", null, ana.Token, ana.BusinessId);
        var missing = await host.PostAsync($"/api/business/team/{Guid.CreateVersion7()}/promote", null, ana.Token, ana.BusinessId);
        var teamAfter = await ApiTestHost.JsonOf(await host.GetAsync("/api/business/team", beto.Token, ana.BusinessId));

        Assert.Equal(2, team.GetArrayLength());
        Assert.Equal(("ana@correo.com", "owner"), (team[0].GetProperty("email").GetString(), team[0].GetProperty("role").GetString()));
        Assert.Equal(HttpStatusCode.Forbidden, asEmployee.StatusCode);
        Assert.Equal(HttpStatusCode.OK, promote.StatusCode);
        Assert.Equal("owner", (await ApiTestHost.JsonOf(promote)).GetProperty("role").GetString());
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal(2, teamAfter.GetArrayLength());
    }
}
