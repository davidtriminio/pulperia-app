using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Pulperia.Api;
using Pulperia.Domain.Access;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Accounts;

/// <summary>T066: negocio activo en cada petición, con comprobación de pertenencia (RF-6, RF-50).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ActiveBusinessTests(PostgresFixture postgres)
{
    // ---- servicio

    [Fact]
    public async Task Un_miembro_activo_recibe_su_rol_en_ese_negocio()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration("ana@correo.com"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com"));
        kit.Db.Memberships.Add(new MembershipEntity
        {
            UserId = ana.UserId, BusinessId = beto.BusinessId, Role = Role.Employee, Status = MembershipStatus.Active,
        });
        await kit.Db.SaveChangesAsync();

        Assert.Equal(Role.Owner, await kit.Service.AuthorizeBusinessAsync(ana.UserId, ana.BusinessId));
        Assert.Equal(Role.Employee, await kit.Service.AuthorizeBusinessAsync(ana.UserId, beto.BusinessId));
    }

    [Fact]
    public async Task Un_negocio_ajeno_o_inexistente_o_una_baja_no_dan_acceso()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration("ana@correo.com"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com"));
        var removed = await kit.RegisterAsync(Registration("carla@correo.com"));
        kit.Db.Memberships.Add(new MembershipEntity
        {
            UserId = removed.UserId, BusinessId = beto.BusinessId, Role = Role.Employee,
            Status = MembershipStatus.Removed, RemovedAt = Start.UtcDateTime,
        });
        await kit.Db.SaveChangesAsync();

        Assert.Null(await kit.Service.AuthorizeBusinessAsync(ana.UserId, beto.BusinessId));
        Assert.Null(await kit.Service.AuthorizeBusinessAsync(ana.UserId, Guid.CreateVersion7()));
        Assert.Null(await kit.Service.AuthorizeBusinessAsync(removed.UserId, beto.BusinessId));
    }

    // ---- HTTP, con una ruta de prueba protegida

    private static void MapProbe(WebApplication app) =>
        app.MapGet("/api/probe", (HttpContext context) =>
        {
            var active = context.GetActiveBusiness();
            return Results.Json(new { userId = active.UserId, businessId = active.BusinessId, role = active.Role.Id() });
        }).RequireBusiness();

    private static async Task<(string Token, Guid UserId, Guid BusinessId)> Account(
        ApiTestHost host, string email, string businessName)
    {
        var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
        {
            email, password = "contrasena1", businessName, amountMode = "two_decimals", quantityMode = "fractional",
        }));
        var login = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
        return (login.GetProperty("accessToken").GetString()!, register.GetProperty("userId").GetGuid(),
            register.GetProperty("businessId").GetGuid());
    }

    [Fact]
    public async Task Una_peticion_al_propio_negocio_pasa_con_el_rol_del_usuario()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");

        var response = await host.GetAsync("/api/probe", ana.Token, ana.BusinessId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await ApiTestHost.JsonOf(response);
        Assert.Equal(("owner", ana.BusinessId, ana.UserId),
            (json.GetProperty("role").GetString(), json.GetProperty("businessId").GetGuid(), json.GetProperty("userId").GetGuid()));
    }

    [Fact]
    public async Task Una_peticion_a_un_negocio_ajeno_recibe_rechazo()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");
        var beto = await Account(host, "beto@correo.com", "Abarrotes Beto");

        var response = await host.GetAsync("/api/probe", ana.Token, beto.BusinessId);
        var unknown = await host.GetAsync("/api/probe", ana.Token, Guid.CreateVersion7());

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal("forbidden", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        // Un negocio que no existe se rechaza igual que uno ajeno: no se revela cuál existe.
        Assert.Equal(HttpStatusCode.Forbidden, unknown.StatusCode);
    }

    [Fact]
    public async Task El_rol_depende_del_negocio_activo_de_cada_peticion()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");
        var beto = await Account(host, "beto@correo.com", "Abarrotes Beto");
        host.Db.Memberships.Add(new MembershipEntity
        {
            UserId = ana.UserId, BusinessId = beto.BusinessId, Role = Role.Employee, Status = MembershipStatus.Active,
        });
        await host.Db.SaveChangesAsync();

        var own = await ApiTestHost.JsonOf(await host.GetAsync("/api/probe", ana.Token, ana.BusinessId));
        var other = await ApiTestHost.JsonOf(await host.GetAsync("/api/probe", ana.Token, beto.BusinessId));

        Assert.Equal("owner", own.GetProperty("role").GetString());
        Assert.Equal("employee", other.GetProperty("role").GetString());
    }

    [Fact]
    public async Task Quitar_a_alguien_le_cierra_el_acceso_en_la_siguiente_peticion()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");
        var beto = await Account(host, "beto@correo.com", "Abarrotes Beto");
        var membership = new MembershipEntity
        {
            UserId = ana.UserId, BusinessId = beto.BusinessId, Role = Role.Employee, Status = MembershipStatus.Active,
        };
        host.Db.Memberships.Add(membership);
        await host.Db.SaveChangesAsync();
        Assert.Equal(HttpStatusCode.OK, (await host.GetAsync("/api/probe", ana.Token, beto.BusinessId)).StatusCode);

        membership.Status = MembershipStatus.Removed;
        membership.RemovedAt = DateTime.UtcNow;
        await host.Db.SaveChangesAsync();

        Assert.Equal(HttpStatusCode.Forbidden, (await host.GetAsync("/api/probe", ana.Token, beto.BusinessId)).StatusCode);
    }

    [Fact]
    public async Task Sin_token_o_con_token_invalido_la_respuesta_es_401_antes_de_mirar_el_negocio()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");

        var none = await host.GetAsync("/api/probe", businessId: ana.BusinessId);
        var bad = await host.GetAsync("/api/probe", "desconocido", ana.BusinessId);

        Assert.Equal(HttpStatusCode.Unauthorized, none.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, bad.StatusCode);
    }

    [Fact]
    public async Task Sin_cabecera_de_negocio_o_con_una_mal_formada_responde_400_business_required()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");

        var missing = await host.GetAsync("/api/probe", ana.Token);
        using var malformed = new HttpRequestMessage(HttpMethod.Get, "/api/probe");
        malformed.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ana.Token);
        malformed.Headers.Add("X-Business-Id", "no-es-un-guid");
        var bad = await host.Client.SendAsync(malformed);

        foreach (var response in new[] { missing, bad })
        {
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal("business_required", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        }
    }

    [Fact]
    public async Task Tras_cerrar_sesion_el_token_no_pasa_el_filtro()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, MapProbe);
        var ana = await Account(host, "ana@correo.com", "Pulpería Ana");
        await host.PostAsync("/api/auth/logout", null, ana.Token);

        var response = await host.GetAsync("/api/probe", ana.Token, ana.BusinessId);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
