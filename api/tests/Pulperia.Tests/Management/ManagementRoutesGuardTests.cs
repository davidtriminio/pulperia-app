using System.Net;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.Routing.Patterns;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Pulperia.Domain.Access;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Management;

/// <summary>
/// T072: todas las rutas de gestión del negocio rechazan a un empleado (RF-13). El test recorre
/// las rutas reales del servidor, así que una ruta nueva bajo <c>/api/business</c> sin proteger
/// lo hace fallar.
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ManagementRoutesGuardTests(PostgresFixture postgres)
{
    private static readonly string[] ExpectedRoutes =
    [
        "DELETE /api/business/invitations/{id:guid}",
        "DELETE /api/business/team/{userId:guid}",
        "GET /api/business",
        "GET /api/business/invitations",
        "GET /api/business/team",
        "PATCH /api/business",
        "POST /api/business/invitations",
        "POST /api/business/team/{userId:guid}/promote",
    ];

    private static IEnumerable<(string Method, string Pattern)> ManagementRoutes(ApiTestHost host) =>
        host.App.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(e => e.RoutePattern.RawText is { } raw && (raw.TrimEnd('/') == "/api/business" || raw.StartsWith("/api/business/")))
            .SelectMany(e => e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Select(m => (m, e.RoutePattern.RawText!.TrimEnd('/'))));

    private static string Fill(string pattern) =>
        System.Text.RegularExpressions.Regex.Replace(pattern, @"\{[^}]+\}", _ => Guid.CreateVersion7().ToString());

    [Fact]
    public async Task Toda_ruta_de_gestion_devuelve_rechazo_a_un_empleado_aunque_el_cuerpo_este_vacio()
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

        var routes = ManagementRoutes(host).ToList();

        Assert.Equal(ExpectedRoutes, routes.Select(r => $"{r.Method} {r.Pattern}").Order(StringComparer.Ordinal));
        foreach (var (method, pattern) in routes)
        {
            var response = await host.SendJsonAsync(
                new HttpMethod(method), Fill(pattern), method is "POST" or "PATCH" ? "{}" : null, beto.Token, ana.BusinessId);

            Assert.True(
                response.StatusCode == HttpStatusCode.Forbidden,
                $"{method} {pattern} devolvió {(int)response.StatusCode} a un empleado");
            Assert.Equal("forbidden", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        }

        // Y al dueño no se le rechaza por rol en ninguna: la protección no es un 403 para todos.
        foreach (var (method, pattern) in routes)
        {
            var response = await host.SendJsonAsync(
                new HttpMethod(method), Fill(pattern), method is "POST" or "PATCH" ? "{}" : null, ana.Token, ana.BusinessId);

            Assert.NotEqual(HttpStatusCode.Forbidden, response.StatusCode);
        }
    }
}
