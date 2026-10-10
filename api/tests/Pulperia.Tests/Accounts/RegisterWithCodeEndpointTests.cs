using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Management;
using Pulperia.Domain.Access;
using Pulperia.Domain.Invitations;
using Pulperia.Infrastructure.Management;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Accounts;

/// <summary>T203: <c>POST /api/auth/register</c> con <c>invitationCode</c> sobre la API real (RF-105 a RF-107, D-32).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class RegisterWithCodeEndpointTests(PostgresFixture postgres)
{
    private static async Task<(Guid UserId, Guid BusinessId)> RegisterOwner(ApiTestHost host)
    {
        var response = await host.PostAsync("/api/auth/register", new
        {
            email = "ana@correo.com", password = "contrasena1", businessName = "Pulpería Ana",
            amountMode = "two_decimals", quantityMode = "fractional",
        });
        var json = await ApiTestHost.JsonOf(response);
        return (json.GetProperty("userId").GetGuid(), json.GetProperty("businessId").GetGuid());
    }

    private static async Task<string> NewCode(ApiTestHost host, (Guid UserId, Guid BusinessId) owner)
    {
        var management = new ManagementService(new EfManagementStore(host.Db), TimeProvider.System);
        var result = await management.InviteAsync(owner.BusinessId, Role.Owner, owner.UserId, null);
        return result.Value!.Code;
    }

    [Fact]
    public async Task Con_un_codigo_responde_201_con_el_negocio_al_que_entro()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var owner = await RegisterOwner(host);
        var code = await NewCode(host, owner);

        var response = await host.PostAsync(
            "/api/auth/register", new { email = "dana@correo.com", password = "contrasena1", invitationCode = code });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var json = await ApiTestHost.JsonOf(response);
        Assert.Equal(owner.BusinessId, json.GetProperty("businessId").GetGuid());
        var dana = await host.Db.Users.AsNoTracking().SingleAsync(u => u.Email == "dana@correo.com");
        Assert.Equal(dana.Id, json.GetProperty("userId").GetGuid());
        Assert.Equal(1, await host.Db.Businesses.CountAsync());
        Assert.Equal(InvitationStatus.Accepted, (await host.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task Con_negocio_y_codigo_a_la_vez_responde_400_registration_ambiguous_sin_consumir_nada()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var owner = await RegisterOwner(host);
        var code = await NewCode(host, owner);

        var response = await host.PostAsync("/api/auth/register", new
        {
            email = "dana@correo.com", password = "contrasena1", invitationCode = code,
            businessName = "Otro", amountMode = "integer", quantityMode = "integer",
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("registration_ambiguous", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        Assert.False(await host.Db.Users.AnyAsync(u => u.Email == "dana@correo.com"));
        Assert.Equal(InvitationStatus.Pending, (await host.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task Un_codigo_que_no_sirve_responde_404_invalid_invitation_code()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        await RegisterOwner(host);

        var response = await host.PostAsync(
            "/api/auth/register", new { email = "dana@correo.com", password = "contrasena1", invitationCode = "AAAA-AAAA" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("invalid_invitation_code", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        Assert.False(await host.Db.Users.AnyAsync(u => u.Email == "dana@correo.com"));
    }

    [Fact]
    public async Task Un_correo_ya_registrado_responde_409_y_el_codigo_sigue_pendiente()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var owner = await RegisterOwner(host);
        var code = await NewCode(host, owner);

        var response = await host.PostAsync(
            "/api/auth/register", new { email = "ana@correo.com", password = "contrasena1", invitationCode = code });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("email_taken", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        Assert.Equal(InvitationStatus.Pending, (await host.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task Un_correo_invalido_responde_400_con_su_codigo()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var owner = await RegisterOwner(host);
        var code = await NewCode(host, owner);

        var response = await host.PostAsync(
            "/api/auth/register", new { email = "sin-arroba", password = "contrasena1", invitationCode = code });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("email_invalid", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Los_intentos_de_codigo_se_limitan_por_origen_y_el_limite_no_toca_el_registro_normal()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var owner = await RegisterOwner(host);
        var code = await NewCode(host, owner);
        var body = new { email = "dana@correo.com", password = "contrasena1", invitationCode = "AAAA-AAAA" };

        for (var i = 0; i < 10; i++)
        {
            Assert.Equal(HttpStatusCode.NotFound, (await host.PostAsync("/api/auth/register", body)).StatusCode);
        }
        var blocked = await host.PostAsync(
            "/api/auth/register", new { email = "dana@correo.com", password = "contrasena1", invitationCode = code });
        var normal = await host.PostAsync("/api/auth/register", new
        {
            email = "luz@correo.com", password = "contrasena1", businessName = "Luz",
            amountMode = "integer", quantityMode = "integer",
        });

        Assert.Equal(HttpStatusCode.TooManyRequests, blocked.StatusCode);
        Assert.Equal("too_many_attempts", (await ApiTestHost.JsonOf(blocked)).GetProperty("code").GetString());
        Assert.Equal(HttpStatusCode.Created, normal.StatusCode);
        Assert.Equal(InvitationStatus.Pending, (await host.Db.Invitations.AsNoTracking().SingleAsync()).Status);
    }
}
