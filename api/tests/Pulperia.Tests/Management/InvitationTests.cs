using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Accounts;
using Pulperia.Application.Management;
using Pulperia.Domain.Access;
using Pulperia.Domain.Invitations;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Management;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Management;

/// <summary>T068: crear invitación, listar pendientes del usuario, aceptar y rechazar (RF-10, RF-67, RF-68).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class InvitationTests(PostgresFixture postgres)
{
    private sealed record World(AccountKit Kit, RegisteredAccount Owner, RegisteredAccount Beto);

    private async Task<World> Setup()
    {
        var kit = await CreateAsync(postgres);
        var owner = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        return new World(kit, owner, beto);
    }

    private static async Task<Guid> Invite(World w, string email = "beto@correo.com")
    {
        var result = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, email);
        return result.IsSuccess ? result.Value!.Id : throw new InvalidOperationException(string.Join(",", result.Codes));
    }

    // ---- crear

    [Fact]
    public async Task El_dueno_invita_y_queda_una_invitacion_pendiente_con_el_correo_normalizado()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "  Carla@Correo.com ");

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        var invitation = await w.Kit.Db.Invitations.AsNoTracking().SingleAsync();
        Assert.Equal(result.Value!.Id, invitation.Id);
        Assert.Equal(("carla@correo.com", InvitationStatus.Pending, w.Owner.BusinessId, w.Owner.UserId, Start.UtcDateTime),
            (invitation.Email, invitation.Status, invitation.BusinessId, invitation.CreatedBy, invitation.CreatedAt));
    }

    [Fact]
    public async Task Un_empleado_no_puede_invitar()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Employee, w.Beto.UserId, "carla@correo.com");

        Assert.Equal(["forbidden"], result.Codes);
        Assert.Empty(w.Kit.Db.Invitations);
    }

    [Theory]
    [InlineData("")]
    [InlineData("sin-arroba")]
    public async Task Un_correo_invalido_se_rechaza(string email)
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, email);

        Assert.Equal(["email_invalid"], result.Codes);
    }

    [Fact]
    public async Task Invitar_a_quien_ya_es_miembro_activo_se_rechaza_pero_a_un_removido_se_permite()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var carla = await w.Kit.RegisterAsync(Registration("carla@correo.com", businessName: "Carla"));
        w.Kit.Db.Memberships.AddRange(
            new MembershipEntity { UserId = w.Beto.UserId, BusinessId = w.Owner.BusinessId, Role = Role.Employee },
            new MembershipEntity
            {
                UserId = carla.UserId, BusinessId = w.Owner.BusinessId, Role = Role.Employee,
                Status = MembershipStatus.Removed, RemovedAt = Start.UtcDateTime,
            });
        await w.Kit.Db.SaveChangesAsync();

        var member = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "BETO@correo.com");
        var owner = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "ana@correo.com");
        var removed = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "carla@correo.com");

        Assert.Equal(["already_member"], member.Codes);
        Assert.Equal(["already_member"], owner.Codes);
        Assert.True(removed.IsSuccess);
    }

    [Fact]
    public async Task Una_segunda_invitacion_pendiente_al_mismo_correo_se_rechaza_hasta_que_la_primera_se_resuelva()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var first = await Invite(w);

        var duplicate = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "Beto@correo.com");
        await w.Kit.Management.RejectInvitationAsync(w.Beto.UserId, first);
        var again = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "beto@correo.com");

        Assert.Equal(["invitation_already_pending"], duplicate.Codes);
        Assert.True(again.IsSuccess);
    }

    [Fact]
    public async Task Dos_negocios_pueden_invitar_al_mismo_correo()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        Assert.True((await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "carla@correo.com")).IsSuccess);
        Assert.True((await w.Kit.Management.InviteAsync(w.Beto.BusinessId, Role.Owner, w.Beto.UserId, "carla@correo.com")).IsSuccess);
    }

    // ---- listar las del usuario (RF-67)

    [Fact]
    public async Task El_usuario_ve_sus_invitaciones_pendientes_con_el_nombre_del_negocio()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);

        var offers = await w.Kit.Management.ListInvitationsForUserAsync(w.Beto.UserId);

        var offer = Assert.Single(offers);
        Assert.Equal((id, w.Owner.BusinessId, "Pulpería Ana"), (offer.Id, offer.BusinessId, offer.BusinessName));
    }

    [Fact]
    public async Task Quien_crea_su_cuenta_despues_con_ese_correo_ve_la_invitacion()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await Invite(w, "nuevo@correo.com");

        var nuevo = await w.Kit.RegisterAsync(Registration("Nuevo@Correo.com", businessName: "Nuevo"));

        Assert.Single(await w.Kit.Management.ListInvitationsForUserAsync(nuevo.UserId));
    }

    [Fact]
    public async Task No_se_listan_las_de_otro_correo_ni_las_ya_resueltas()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var forBeto = await Invite(w);
        await Invite(w, "carla@correo.com");
        await w.Kit.Management.RejectInvitationAsync(w.Beto.UserId, forBeto);

        Assert.Empty(await w.Kit.Management.ListInvitationsForUserAsync(w.Beto.UserId));
        Assert.Empty(await w.Kit.Management.ListInvitationsForUserAsync(Guid.CreateVersion7()));
    }

    // ---- aceptar

    [Fact]
    public async Task Al_aceptar_entra_como_empleado_aunque_ya_pertenezca_a_otros_negocios()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);

        var result = await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, id);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        Assert.Equal((w.Owner.BusinessId, "Pulpería Ana", Role.Employee), (result.Value!.Id, result.Value.Name, result.Value.Role));
        var roles = (await w.Kit.Service.ListBusinessesAsync(w.Beto.UserId)).ToDictionary(b => b.Id, b => b.Role);
        Assert.Equal(Role.Owner, roles[w.Beto.BusinessId]);
        Assert.Equal(Role.Employee, roles[w.Owner.BusinessId]);
        Assert.Equal(InvitationStatus.Accepted, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task Aceptar_reactiva_a_un_removido_como_empleado_aunque_antes_fuera_dueno()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        w.Kit.Db.Memberships.Add(new MembershipEntity
        {
            UserId = w.Beto.UserId, BusinessId = w.Owner.BusinessId, Role = Role.Owner,
            Status = MembershipStatus.Removed, RemovedAt = Start.UtcDateTime, FinalSyncUsed = true,
        });
        await w.Kit.Db.SaveChangesAsync();
        var id = await Invite(w);

        Assert.True((await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, id)).IsSuccess);

        var membership = await w.Kit.Db.Memberships.AsNoTracking()
            .SingleAsync(m => m.UserId == w.Beto.UserId && m.BusinessId == w.Owner.BusinessId);
        Assert.Equal((Role.Employee, MembershipStatus.Active, null, false),
            (membership.Role, membership.Status, membership.RemovedAt, membership.FinalSyncUsed));
    }

    [Fact]
    public async Task Otro_usuario_no_puede_aceptar_ni_rechazar_una_invitacion_ajena()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);
        var carla = await w.Kit.RegisterAsync(Registration("carla@correo.com", businessName: "Carla"));

        var accept = await w.Kit.Management.AcceptInvitationAsync(carla.UserId, id);
        var reject = await w.Kit.Management.RejectInvitationAsync(carla.UserId, id);

        Assert.Equal(["invitation_not_invitee"], accept.Codes);
        Assert.Equal(["invitation_not_invitee"], reject.Codes);
        Assert.Equal(InvitationStatus.Pending, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
        Assert.DoesNotContain(w.Kit.Db.Memberships, m => m.UserId == carla.UserId && m.BusinessId == w.Owner.BusinessId);
    }

    [Fact]
    public async Task Una_invitacion_resuelta_no_se_puede_aceptar_ni_rechazar_otra_vez()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var accepted = await Invite(w);
        await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, accepted);

        Assert.Equal(["invitation_not_pending"], (await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, accepted)).Codes);
        Assert.Equal(["invitation_not_pending"], (await w.Kit.Management.RejectInvitationAsync(w.Beto.UserId, accepted)).Codes);
    }

    [Fact]
    public async Task Una_invitacion_inexistente_se_rechaza()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, Guid.CreateVersion7());

        Assert.Equal(["invitation_not_found"], result.Codes);
    }

    [Fact]
    public async Task Dos_aceptaciones_a_la_vez_solo_dejan_pasar_una()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);
        var connectionString = w.Kit.Db.Database.GetConnectionString()!;

        async Task<bool> Accept()
        {
            await using var db = PostgresFixture.NewContext(connectionString);
            var service = new ManagementService(new EfManagementStore(db), w.Kit.Clock);
            return (await service.AcceptInvitationAsync(w.Beto.UserId, id)).IsSuccess;
        }

        var results = await Task.WhenAll(Accept(), Accept());

        Assert.Equal(1, results.Count(ok => ok));
        Assert.Single(w.Kit.Db.Memberships.Where(m => m.UserId == w.Beto.UserId && m.BusinessId == w.Owner.BusinessId));
    }

    // ---- rechazar

    [Fact]
    public async Task Rechazar_la_marca_y_no_crea_pertenencia()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);

        var result = await w.Kit.Management.RejectInvitationAsync(w.Beto.UserId, id);

        Assert.True(result.IsSuccess);
        Assert.Equal(InvitationStatus.Rejected, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
        Assert.DoesNotContain(w.Kit.Db.Memberships, m => m.UserId == w.Beto.UserId && m.BusinessId == w.Owner.BusinessId);
        Assert.Equal(["invitation_not_pending"], (await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, id)).Codes);
    }

    // ---- HTTP

    private static async Task<(string Token, Guid UserId, Guid BusinessId)> Account(ApiTestHost host, string email, string business)
    {
        var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
        {
            email, password = "contrasena1", businessName = business, amountMode = "two_decimals", quantityMode = "fractional",
        }));
        var login = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
        return (login.GetProperty("accessToken").GetString()!, register.GetProperty("userId").GetGuid(),
            register.GetProperty("businessId").GetGuid());
    }

    [Fact]
    public async Task Flujo_completo_por_HTTP_invitar_ver_y_aceptar()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");
        var beto = await Account(host, "beto@correo.com", "Abarrotes Beto");

        var invite = await host.PostAsync("/api/business/invitations", new { email = "beto@correo.com" }, ana.Token, ana.BusinessId);
        var pending = await ApiTestHost.JsonOf(await host.GetAsync("/api/invitations", beto.Token));
        var id = pending[0].GetProperty("id").GetGuid();
        var accept = await host.PostAsync($"/api/invitations/{id}/accept", null, beto.Token);
        var businesses = await ApiTestHost.JsonOf(await host.GetAsync("/api/businesses", beto.Token));

        Assert.Equal(HttpStatusCode.Created, invite.StatusCode);
        Assert.Equal("pending", (await ApiTestHost.JsonOf(invite)).GetProperty("status").GetString());
        Assert.Equal("Pulpería Ana", pending[0].GetProperty("businessName").GetString());
        Assert.Equal(HttpStatusCode.OK, accept.StatusCode);
        Assert.Equal("employee", (await ApiTestHost.JsonOf(accept)).GetProperty("role").GetString());
        Assert.Equal(2, businesses.GetArrayLength());
    }

    [Fact]
    public async Task Por_HTTP_un_empleado_recibe_403_al_invitar_y_los_estados_se_traducen()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");
        var beto = await Account(host, "beto@correo.com", "Abarrotes Beto");
        var carla = await Account(host, "carla@correo.com", "Carla");
        await host.PostAsync("/api/business/invitations", new { email = "beto@correo.com" }, ana.Token, ana.BusinessId);
        var id = (await ApiTestHost.JsonOf(await host.GetAsync("/api/invitations", beto.Token)))[0].GetProperty("id").GetGuid();
        await host.PostAsync($"/api/invitations/{id}/accept", null, beto.Token);

        var employeeInvites = await host.PostAsync(
            "/api/business/invitations", new { email = "x@correo.com" }, beto.Token, ana.BusinessId);
        var again = await host.PostAsync($"/api/invitations/{id}/accept", null, beto.Token);
        var stranger = await host.PostAsync($"/api/invitations/{id}/reject", null, carla.Token);
        var missing = await host.PostAsync($"/api/invitations/{Guid.CreateVersion7()}/accept", null, beto.Token);
        var noToken = await host.GetAsync("/api/invitations");
        var badEmail = await host.PostAsync("/api/business/invitations", new { email = "no" }, ana.Token, ana.BusinessId);

        Assert.Equal(HttpStatusCode.Forbidden, employeeInvites.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, stranger.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, noToken.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, badEmail.StatusCode);
        Assert.Equal("invitation_not_pending", (await ApiTestHost.JsonOf(again)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Por_HTTP_rechazar_responde_204()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");
        var beto = await Account(host, "beto@correo.com", "Abarrotes Beto");
        await host.PostAsync("/api/business/invitations", new { email = "beto@correo.com" }, ana.Token, ana.BusinessId);
        var id = (await ApiTestHost.JsonOf(await host.GetAsync("/api/invitations", beto.Token)))[0].GetProperty("id").GetGuid();

        var reject = await host.PostAsync($"/api/invitations/{id}/reject", null, beto.Token);

        Assert.Equal(HttpStatusCode.NoContent, reject.StatusCode);
        Assert.Equal(0, (await ApiTestHost.JsonOf(await host.GetAsync("/api/invitations", beto.Token))).GetArrayLength());
    }
}
