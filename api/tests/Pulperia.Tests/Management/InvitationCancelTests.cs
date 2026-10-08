using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;
using Pulperia.Domain.Invitations;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Management;

/// <summary>T069: cancelar una invitación pendiente (RF-69) y listar las pendientes del negocio.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class InvitationCancelTests(PostgresFixture postgres)
{
    private sealed record World(AccountKit Kit, RegisteredAccount Owner, RegisteredAccount Beto);

    private async Task<World> Setup()
    {
        var kit = await CreateAsync(postgres);
        var owner = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        return new World(kit, owner, beto);
    }

    private static async Task<Guid> Invite(World w, string email = "beto@correo.com") =>
        (await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, email)).Value!.Id;

    [Fact]
    public async Task Una_invitacion_cancelada_no_puede_aceptarse()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);

        var cancel = await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, id);
        var accept = await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, id);

        Assert.True(cancel.IsSuccess, string.Join(",", cancel.Codes));
        Assert.Equal(["invitation_not_pending"], accept.Codes);
        Assert.Equal(InvitationStatus.Cancelled, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
        Assert.DoesNotContain(w.Kit.Db.Memberships, m => m.UserId == w.Beto.UserId && m.BusinessId == w.Owner.BusinessId);
        Assert.Empty(await w.Kit.Management.ListInvitationsForUserAsync(w.Beto.UserId));
    }

    [Fact]
    public async Task Un_empleado_no_puede_cancelar()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);

        var result = await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Employee, id);

        Assert.Equal(["forbidden"], result.Codes);
        Assert.Equal(InvitationStatus.Pending, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task Un_dueno_no_puede_cancelar_la_invitacion_de_otro_negocio()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);

        var result = await w.Kit.Management.CancelInvitationAsync(w.Beto.BusinessId, Role.Owner, id);
        var missing = await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, Guid.CreateVersion7());

        Assert.Equal(["invitation_not_found"], result.Codes);
        Assert.Equal(["invitation_not_found"], missing.Codes);
        Assert.Equal(InvitationStatus.Pending, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task Cancelar_una_ya_resuelta_o_ya_cancelada_se_rechaza()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var accepted = await Invite(w);
        await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, accepted);
        var cancelled = await Invite(w, "carla@correo.com");
        await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, cancelled);

        var onAccepted = await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, accepted);
        var onCancelled = await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, cancelled);

        Assert.Equal(["invitation_not_pending"], onAccepted.Codes);
        Assert.Equal(["invitation_not_pending"], onCancelled.Codes);
    }

    [Fact]
    public async Task Despues_de_cancelar_se_puede_invitar_de_nuevo_al_mismo_correo()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var id = await Invite(w);
        await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, id);

        var again = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, "beto@correo.com");

        Assert.True(again.IsSuccess);
    }

    // ---- listar las pendientes del negocio

    [Fact]
    public async Task El_dueno_lista_las_pendientes_de_su_negocio_y_no_las_de_otros_ni_las_resueltas()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var pending = await Invite(w, "carla@correo.com");
        var cancelled = await Invite(w, "dana@correo.com");
        await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, cancelled);
        await w.Kit.Management.InviteAsync(w.Beto.BusinessId, Role.Owner, w.Beto.UserId, "elena@correo.com");

        var list = await w.Kit.Management.ListBusinessInvitationsAsync(w.Owner.BusinessId, Role.Owner);

        Assert.True(list.IsSuccess);
        var only = Assert.Single(list.Value!);
        Assert.Equal((pending, "carla@correo.com"), (only.Id, only.Email));
    }

    [Fact]
    public async Task Un_empleado_no_puede_listar_las_invitaciones_del_negocio()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var list = await w.Kit.Management.ListBusinessInvitationsAsync(w.Owner.BusinessId, Role.Employee);

        Assert.Equal(["forbidden"], list.Codes);
    }

    // ---- HTTP

    [Fact]
    public async Task Por_HTTP_listar_y_cancelar_y_el_invitado_ya_no_la_ve()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        async Task<(string Token, Guid BusinessId)> Account(string email)
        {
            var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
            {
                email, password = "contrasena1", businessName = email, amountMode = "two_decimals", quantityMode = "fractional",
            }));
            var login = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
            return (login.GetProperty("accessToken").GetString()!, register.GetProperty("businessId").GetGuid());
        }
        var ana = await Account("ana@correo.com");
        var beto = await Account("beto@correo.com");
        var id = (await ApiTestHost.JsonOf(await host.PostAsync(
            "/api/business/invitations", new { email = "beto@correo.com" }, ana.Token, ana.BusinessId))).GetProperty("id").GetGuid();

        var list = await ApiTestHost.JsonOf(await host.GetAsync("/api/business/invitations", ana.Token, ana.BusinessId));
        var cancel = await host.DeleteAsync($"/api/business/invitations/{id}", ana.Token, ana.BusinessId);
        var again = await host.DeleteAsync($"/api/business/invitations/{id}", ana.Token, ana.BusinessId);
        var foreign = await host.DeleteAsync($"/api/business/invitations/{id}", beto.Token, beto.BusinessId);
        var visible = await ApiTestHost.JsonOf(await host.GetAsync("/api/invitations", beto.Token));

        Assert.Equal("beto@correo.com", list[0].GetProperty("email").GetString());
        Assert.Equal(HttpStatusCode.NoContent, cancel.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(0, visible.GetArrayLength());
    }
}
