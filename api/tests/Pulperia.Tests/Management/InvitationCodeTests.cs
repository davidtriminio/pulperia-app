using System.Net;
using System.Text.Json;
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

/// <summary>T183: código de invitación, con o sin correo, y su canje (RF-92, RF-93, RF-94, D-28).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class InvitationCodeTests(PostgresFixture postgres)
{
    private sealed record World(AccountKit Kit, RegisteredAccount Owner, RegisteredAccount Beto, RegisteredAccount Carla);

    private async Task<World> Setup()
    {
        var kit = await CreateAsync(postgres);
        var owner = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        var carla = await kit.RegisterAsync(Registration("carla@correo.com", businessName: "Carla"));
        return new World(kit, owner, beto, carla);
    }

    private static async Task<InvitationView> Invite(World w, string? email = null)
    {
        var result = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, email);
        return result.IsSuccess ? result.Value! : throw new InvalidOperationException(string.Join(",", result.Codes));
    }

    // ---- crear (RF-92)

    [Fact]
    public async Task Una_invitacion_sin_correo_se_crea_con_su_codigo_y_sin_email()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var invitation = await Invite(w);

        Assert.Null(invitation.Email);
        Assert.Matches("^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$", invitation.Code);
        var stored = await w.Kit.Db.Invitations.AsNoTracking().SingleAsync();
        Assert.Equal((null, InvitationStatus.Pending, w.Owner.UserId), (stored.Email, stored.Status, stored.CreatedBy));
        Assert.Equal(invitation.Code.Replace("-", ""), stored.Code);
    }

    [Fact]
    public async Task Una_invitacion_con_correo_tambien_lleva_codigo()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var invitation = await Invite(w, "Dana@Correo.com");

        Assert.Equal("dana@correo.com", invitation.Email);
        Assert.Matches("^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$", invitation.Code);
    }

    [Fact]
    public async Task Varias_invitaciones_sin_correo_a_la_vez_son_validas_y_cada_una_tiene_un_codigo_distinto()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var invitations = new List<InvitationView>();
        for (var i = 0; i < 30; i++)
        {
            invitations.Add(await Invite(w));
        }

        Assert.Equal(30, invitations.Select(i => i.Code).Distinct().Count());
    }

    [Fact]
    public async Task Un_empleado_no_puede_crear_invitaciones_con_codigo()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var result = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Employee, w.Beto.UserId, null);

        Assert.Equal(["forbidden"], result.Codes);
    }

    [Fact]
    public async Task El_dueno_ve_el_codigo_de_las_pendientes_pero_no_el_de_las_resueltas()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var withCode = await Invite(w);
        var byEmail = await Invite(w, "dana@correo.com");
        var cancelled = await Invite(w);
        await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, cancelled.Id);

        var list = await w.Kit.Management.ListBusinessInvitationsAsync(w.Owner.BusinessId, Role.Owner);

        Assert.Equal(
            [(withCode.Id, withCode.Code), (byEmail.Id, byEmail.Code)],
            list.Value!.Select(i => (i.Id, i.Code)));
    }

    // ---- canjear (RF-93)

    [Fact]
    public async Task Una_cuenta_cualquiera_canjea_una_invitacion_sin_correo_y_entra_como_empleado()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);

        var result = await w.Kit.Management.RedeemInvitationCodeAsync(w.Carla.UserId, invitation.Code);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        Assert.Equal((w.Owner.BusinessId, "Pulpería Ana", Role.Employee), (result.Value!.Id, result.Value.Name, result.Value.Role));
        Assert.Equal(Role.Employee, await w.Kit.Service.AuthorizeBusinessAsync(w.Carla.UserId, w.Owner.BusinessId));
        Assert.Equal(Role.Owner, await w.Kit.Service.AuthorizeBusinessAsync(w.Carla.UserId, w.Carla.BusinessId));
        Assert.Equal(InvitationStatus.Accepted, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task El_codigo_de_una_invitacion_con_correo_se_puede_canjear_desde_otro_correo_y_la_consume()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w, "beto@correo.com");

        var result = await w.Kit.Management.RedeemInvitationCodeAsync(w.Carla.UserId, invitation.Code);

        Assert.True(result.IsSuccess);
        Assert.Empty(await w.Kit.Management.ListInvitationsForUserAsync(w.Beto.UserId));
        Assert.Equal(["invitation_not_pending"], (await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, invitation.Id)).Codes);
    }

    [Theory]
    [InlineData("MINUSCULAS")]
    [InlineData("CON ESPACIOS")]
    [InlineData("SIN GUION")]
    public async Task El_canje_ignora_mayusculas_espacios_y_guiones(string style)
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var shown = (await Invite(w)).Code;
        var typed = style switch
        {
            "MINUSCULAS" => shown.ToLowerInvariant(),
            "CON ESPACIOS" => "  " + shown.Replace("-", " ") + " ",
            _ => shown.Replace("-", ""),
        };

        var result = await w.Kit.Management.RedeemInvitationCodeAsync(w.Carla.UserId, typed);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
    }

    [Fact]
    public async Task Un_removido_que_canjea_un_codigo_vuelve_como_empleado()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        w.Kit.Db.Memberships.Add(new MembershipEntity
        {
            UserId = w.Carla.UserId, BusinessId = w.Owner.BusinessId, Role = Role.Owner,
            Status = MembershipStatus.Removed, RemovedAt = Start.UtcDateTime, FinalSyncUsed = true,
        });
        await w.Kit.Db.SaveChangesAsync();
        var invitation = await Invite(w);

        Assert.True((await w.Kit.Management.RedeemInvitationCodeAsync(w.Carla.UserId, invitation.Code)).IsSuccess);

        var membership = await w.Kit.Db.Memberships.AsNoTracking()
            .SingleAsync(m => m.UserId == w.Carla.UserId && m.BusinessId == w.Owner.BusinessId);
        Assert.Equal((Role.Employee, MembershipStatus.Active, null, false),
            (membership.Role, membership.Status, membership.RemovedAt, membership.FinalSyncUsed));
    }

    [Fact]
    public async Task Un_miembro_activo_que_canjea_un_codigo_de_su_negocio_no_lo_consume_ni_pierde_su_rol()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);

        var result = await w.Kit.Management.RedeemInvitationCodeAsync(w.Owner.UserId, invitation.Code);

        Assert.Equal(["already_member"], result.Codes);
        Assert.Equal(Role.Owner, await w.Kit.Service.AuthorizeBusinessAsync(w.Owner.UserId, w.Owner.BusinessId));
        Assert.Equal(InvitationStatus.Pending, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
        Assert.True((await w.Kit.Management.RedeemInvitationCodeAsync(w.Carla.UserId, invitation.Code)).IsSuccess);
    }

    [Fact]
    public async Task Aceptar_por_correo_tampoco_degrada_a_quien_ya_es_dueno_del_negocio()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w, "beto@correo.com");
        w.Kit.Db.Memberships.Add(new MembershipEntity { UserId = w.Beto.UserId, BusinessId = w.Owner.BusinessId, Role = Role.Owner });
        await w.Kit.Db.SaveChangesAsync();

        var result = await w.Kit.Management.AcceptInvitationAsync(w.Beto.UserId, invitation.Id);

        Assert.True(result.IsSuccess);
        Assert.Equal(Role.Owner, await w.Kit.Service.AuthorizeBusinessAsync(w.Beto.UserId, w.Owner.BusinessId));
    }

    // ---- rechazos (RF-94)

    [Fact]
    public async Task Un_codigo_usado_cancelado_inexistente_o_mal_formado_da_el_mismo_rechazo_y_no_agrega_a_nadie()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var used = await Invite(w);
        await w.Kit.Management.RedeemInvitationCodeAsync(w.Beto.UserId, used.Code);
        var cancelled = await Invite(w);
        await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, cancelled.Id);

        var attempts = new[] { used.Code, cancelled.Code, "ZZZZ-ZZZZ", "no-es-un-codigo", "", "   " };
        var results = new List<AccountResult<BusinessSummary>>();
        foreach (var attempt in attempts)
        {
            results.Add(await w.Kit.Management.RedeemInvitationCodeAsync(w.Carla.UserId, attempt));
        }

        Assert.All(results, r => Assert.Equal(["invalid_invitation_code"], r.Codes));
        Assert.Null(await w.Kit.Service.AuthorizeBusinessAsync(w.Carla.UserId, w.Owner.BusinessId));
    }

    [Fact]
    public async Task Dos_personas_canjeando_el_mismo_codigo_a_la_vez_solo_dejan_pasar_a_una()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);
        var connectionString = w.Kit.Db.Database.GetConnectionString()!;

        async Task<bool> Redeem(Guid userId)
        {
            await using var db = PostgresFixture.NewContext(connectionString);
            var service = new ManagementService(new EfManagementStore(db), w.Kit.Clock);
            return (await service.RedeemInvitationCodeAsync(userId, invitation.Code)).IsSuccess;
        }

        var results = await Task.WhenAll(Redeem(w.Beto.UserId), Redeem(w.Carla.UserId));

        Assert.Equal(1, results.Count(ok => ok));
        Assert.Equal(1, await w.Kit.Db.Memberships.CountAsync(m => m.BusinessId == w.Owner.BusinessId && m.Role == Role.Employee));
    }

    // ---- HTTP

    private static async Task<(string Token, Guid UserId, Guid BusinessId)> Account(ApiTestHost host, string email)
    {
        var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
        {
            email, password = "contrasena1", businessName = email, amountMode = "two_decimals", quantityMode = "fractional",
        }));
        var login = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
        return (login.GetProperty("accessToken").GetString()!, register.GetProperty("userId").GetGuid(),
            register.GetProperty("businessId").GetGuid());
    }

    [Fact]
    public async Task Por_HTTP_el_dueno_crea_con_y_sin_correo_ve_el_codigo_y_el_invitado_no_lo_ve()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var ana = await Account(host, "ana@correo.com");
        var beto = await Account(host, "beto@correo.com");

        var codeOnly = await host.SendJsonAsync(HttpMethod.Post, "/api/business/invitations", "{}", ana.Token, ana.BusinessId);
        var byEmail = await host.PostAsync("/api/business/invitations", new { email = "beto@correo.com" }, ana.Token, ana.BusinessId);
        var list = await ApiTestHost.JsonOf(await host.GetAsync("/api/business/invitations", ana.Token, ana.BusinessId));
        var forInvitee = await ApiTestHost.JsonOf(await host.GetAsync("/api/invitations", beto.Token));

        Assert.Equal(HttpStatusCode.Created, codeOnly.StatusCode);
        var created = await ApiTestHost.JsonOf(codeOnly);
        Assert.Equal(JsonValueKind.Null, created.GetProperty("email").ValueKind);
        Assert.Matches("^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$", created.GetProperty("code").GetString()!);
        Assert.Equal(HttpStatusCode.Created, byEmail.StatusCode);
        Assert.Equal(2, list.GetArrayLength());
        Assert.All(list.EnumerateArray(), item => Assert.True(item.TryGetProperty("code", out _)));
        var offer = Assert.Single(forInvitee.EnumerateArray());
        Assert.False(offer.TryGetProperty("code", out _));
    }

    [Fact]
    public async Task Por_HTTP_canjear_responde_200_y_un_segundo_canje_o_un_codigo_malo_responde_404_igual()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var ana = await Account(host, "ana@correo.com");
        var carla = await Account(host, "carla@correo.com");
        var code = (await ApiTestHost.JsonOf(await host.SendJsonAsync(
            HttpMethod.Post, "/api/business/invitations", "{}", ana.Token, ana.BusinessId))).GetProperty("code").GetString();

        var redeem = await host.PostAsync("/api/invitations/redeem", new { code = code!.ToLowerInvariant() }, carla.Token);
        var again = await host.PostAsync("/api/invitations/redeem", new { code }, carla.Token);
        var bad = await host.PostAsync("/api/invitations/redeem", new { code = "ZZZZ-ZZZZ" }, carla.Token);
        var businesses = await ApiTestHost.JsonOf(await host.GetAsync("/api/businesses", carla.Token));

        Assert.Equal(HttpStatusCode.OK, redeem.StatusCode);
        var json = await ApiTestHost.JsonOf(redeem);
        Assert.Equal(("employee", ana.BusinessId), (json.GetProperty("role").GetString(), json.GetProperty("id").GetGuid()));
        Assert.Equal(HttpStatusCode.NotFound, again.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, bad.StatusCode);
        Assert.Equal("invalid_invitation_code", (await ApiTestHost.JsonOf(again)).GetProperty("code").GetString());
        Assert.Equal("invalid_invitation_code", (await ApiTestHost.JsonOf(bad)).GetProperty("code").GetString());
        Assert.Equal(2, businesses.GetArrayLength());
    }

    [Fact]
    public async Task Por_HTTP_canjear_sin_sesion_o_sin_cuerpo_se_rechaza()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var carla = await Account(host, "carla@correo.com");

        var noToken = await host.PostAsync("/api/invitations/redeem", new { code = "ABCD-EFGH" });
        var noBody = await host.SendJsonAsync(HttpMethod.Post, "/api/invitations/redeem", "{}", carla.Token);

        Assert.Equal(HttpStatusCode.Unauthorized, noToken.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, noBody.StatusCode);
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(noBody)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Por_HTTP_el_undecimo_intento_en_un_minuto_se_rechaza_y_solo_a_ese_usuario()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var carla = await Account(host, "carla@correo.com");
        var dana = await Account(host, "dana@correo.com");

        var statuses = new List<HttpStatusCode>();
        for (var i = 0; i < 11; i++)
        {
            statuses.Add((await host.PostAsync("/api/invitations/redeem", new { code = "ZZZZ-ZZZZ" }, carla.Token)).StatusCode);
        }
        var limited = await host.PostAsync("/api/invitations/redeem", new { code = "ZZZZ-ZZZZ" }, carla.Token);
        var other = await host.PostAsync("/api/invitations/redeem", new { code = "ZZZZ-ZZZZ" }, dana.Token);

        Assert.All(statuses.Take(10), s => Assert.Equal(HttpStatusCode.NotFound, s));
        Assert.Equal(HttpStatusCode.TooManyRequests, statuses[10]);
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.Equal("too_many_attempts", (await ApiTestHost.JsonOf(limited)).GetProperty("code").GetString());
        Assert.Equal(HttpStatusCode.NotFound, other.StatusCode);
    }
}
