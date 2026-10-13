using System.Net;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Accounts;

/// <summary>
/// T136: <c>GET /health</c>, para que el despliegue y el monitoreo sepan que la API y su base
/// responden (D-33). No es parte del contrato de la API ni trae datos.
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class HealthEndpointTests(PostgresFixture postgres)
{
    [Fact]
    public async Task Responde_200_sin_autenticar_y_sin_datos()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var response = await host.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal(["status"], body.EnumerateObject().Select(p => p.Name));
        Assert.Equal("ok", body.GetProperty("status").GetString());
    }

    [Fact]
    public async Task Sin_base_de_datos_responde_503_para_que_el_despliegue_lo_note()
    {
        await using var other = await ApiTestHost.StartAsync(
            postgres,
            configuration: new Dictionary<string, string?>
            {
                ["ConnectionStrings:Pulperia"] =
                    "Host=127.0.0.1;Port=1;Database=x;Username=x;Password=x;Timeout=2;Pooling=false",
            });

        var response = await other.GetAsync("/health");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var text = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("Host=", text);
    }

    [Fact]
    public async Task No_es_una_ruta_del_contrato_de_la_api()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var routes = host.App.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Select(e => e.RoutePattern.RawText)
            .Where(raw => raw is "/health")
            .ToList();

        Assert.Single(routes);
        Assert.DoesNotContain("/api/", routes.Single());
    }
}
