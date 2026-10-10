using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Accounts;
using Pulperia.Application.Management;
using Pulperia.Domain.Access;
using Pulperia.Domain.Invitations;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Accounts;

/// <summary>T203: registrarse con un código de invitación, sin negocio propio (RF-105, RF-106, D-32).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class RegistrationWithCodeTests(PostgresFixture postgres)
{
    private sealed record World(AccountKit Kit, RegisteredAccount Owner);

    private async Task<World> Setup()
    {
        var kit = await CreateAsync(postgres);
        var owner = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        return new World(kit, owner);
    }

    private static async Task<InvitationView> Invite(World w, string? email = null)
    {
        var result = await w.Kit.Management.InviteAsync(w.Owner.BusinessId, Role.Owner, w.Owner.UserId, email);
        return result.IsSuccess ? result.Value! : throw new InvalidOperationException(string.Join(",", result.Codes));
    }

    [Fact]
    public async Task Con_un_codigo_pendiente_crea_la_cuenta_como_empleado_sin_negocio_propio()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);

        var result = await w.Kit.Service.RegisterWithInvitationCodeAsync("Dana@Correo.com", Password, invitation.Code);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        Assert.Equal(w.Owner.BusinessId, result.Value!.BusinessId);
        var dana = result.Value.UserId;
        Assert.Equal("dana@correo.com", (await w.Kit.Db.Users.AsNoTracking().SingleAsync(u => u.Id == dana)).Email);
        Assert.Equal(Role.Employee, await w.Kit.Service.AuthorizeBusinessAsync(dana, w.Owner.BusinessId));
        Assert.Equal(1, await w.Kit.Db.Memberships.CountAsync(m => m.UserId == dana));
        Assert.Equal(1, await w.Kit.Db.Businesses.CountAsync());
        Assert.Equal(InvitationStatus.Accepted, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
        Assert.True((await w.Kit.Service.LoginAsync("dana@correo.com", Password)).IsSuccess);
    }

    [Fact]
    public async Task El_codigo_de_una_invitacion_con_correo_vale_desde_otro_correo()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w, "beto@correo.com");

        var result = await w.Kit.Service.RegisterWithInvitationCodeAsync("dana@correo.com", Password, invitation.Code);

        Assert.True(result.IsSuccess);
        Assert.Empty(await w.Kit.Management.ListInvitationsForUserAsync(result.Value!.UserId));
    }

    [Theory]
    [InlineData("MINUSCULAS")]
    [InlineData("CON ESPACIOS")]
    [InlineData("SIN GUION")]
    public async Task Ignora_mayusculas_espacios_y_guiones_del_codigo(string style)
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

        var result = await w.Kit.Service.RegisterWithInvitationCodeAsync("dana@correo.com", Password, typed);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
    }

    [Theory]
    [InlineData("inexistente")]
    [InlineData("usado")]
    [InlineData("cancelado")]
    [InlineData("mal_escrito")]
    [InlineData("vacio")]
    public async Task Un_codigo_que_no_sirve_da_el_mismo_rechazo_y_no_crea_la_cuenta(string kind)
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);
        var typed = kind switch
        {
            "inexistente" => "AAAA-AAAA",
            "usado" => await UsedCode(w, invitation),
            "cancelado" => await CancelledCode(w, invitation),
            "mal_escrito" => "12",
            _ => "",
        };

        var result = await w.Kit.Service.RegisterWithInvitationCodeAsync("dana@correo.com", Password, typed);

        Assert.Equal(["invalid_invitation_code"], result.Codes);
        Assert.False(await w.Kit.Db.Users.AnyAsync(u => u.Email == "dana@correo.com"));
    }

    private static async Task<string> UsedCode(World w, InvitationView invitation)
    {
        var other = await w.Kit.RegisterAsync(Registration("carla@correo.com", businessName: "Carla"));
        await w.Kit.Management.RedeemInvitationCodeAsync(other.UserId, invitation.Code);
        return invitation.Code;
    }

    private static async Task<string> CancelledCode(World w, InvitationView invitation)
    {
        await w.Kit.Management.CancelInvitationAsync(w.Owner.BusinessId, Role.Owner, invitation.Id);
        return invitation.Code;
    }

    [Fact]
    public async Task Un_correo_ya_registrado_se_rechaza_y_el_codigo_no_se_consume()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);

        var result = await w.Kit.Service.RegisterWithInvitationCodeAsync("ANA@correo.com", Password, invitation.Code);

        Assert.Equal(["email_taken"], result.Codes);
        Assert.Equal(InvitationStatus.Pending, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Theory]
    [InlineData("sin-arroba", "contrasena1", "email_invalid")]
    [InlineData("dana@correo.com", "corta", "password_too_short")]
    public async Task Un_correo_o_una_contrasena_invalidos_se_rechazan_sin_consumir_el_codigo(
        string email, string password, string code)
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);

        var result = await w.Kit.Service.RegisterWithInvitationCodeAsync(email, password, invitation.Code);

        Assert.Equal([code], result.Codes);
        Assert.Equal(InvitationStatus.Pending, (await w.Kit.Db.Invitations.AsNoTracking().SingleAsync()).Status);
        Assert.Equal(1, await w.Kit.Db.Users.CountAsync());
    }

    [Fact]
    public async Task Un_codigo_solo_sirve_a_un_registro()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);

        var first = await w.Kit.Service.RegisterWithInvitationCodeAsync("dana@correo.com", Password, invitation.Code);
        var second = await w.Kit.Service.RegisterWithInvitationCodeAsync("elena@correo.com", Password, invitation.Code);

        Assert.True(first.IsSuccess);
        Assert.Equal(["invalid_invitation_code"], second.Codes);
        Assert.False(await w.Kit.Db.Users.AnyAsync(u => u.Email == "elena@correo.com"));
    }

    [Fact]
    public async Task La_cuenta_solo_ve_el_negocio_al_que_entro_y_ninguno_propio()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var invitation = await Invite(w);
        var dana = (await w.Kit.Service.RegisterWithInvitationCodeAsync("dana@correo.com", Password, invitation.Code)).Value!;

        var businesses = await w.Kit.Service.ListBusinessesAsync(dana.UserId);

        Assert.Equal([(w.Owner.BusinessId, Role.Employee)], businesses.Select(b => (b.Id, b.Role)));
    }
}
