using System.Net;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T206: CORS solo para los orígenes configurados (<c>Cors:AllowedOrigins</c>), para la web de
/// Vercel (D-33). Sin configuración no se permite ninguno.
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class CorsTests(PostgresFixture postgres)
{
    private const string Web = "https://pulperia-web.vercel.app";

    private static Dictionary<string, string?> Origins(string value) => new() { ["Cors:AllowedOrigins"] = value };

    private static async Task<HttpResponseMessage> Get(ApiTestHost host, string path, string origin)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        request.Headers.Add("Origin", origin);
        return await host.Client.SendAsync(request);
    }

    private static async Task<HttpResponseMessage> Preflight(
        ApiTestHost host, string path, string origin, string method = "POST",
        string headers = "authorization,content-type,x-business-id")
    {
        using var request = new HttpRequestMessage(HttpMethod.Options, path);
        request.Headers.Add("Origin", origin);
        request.Headers.Add("Access-Control-Request-Method", method);
        request.Headers.Add("Access-Control-Request-Headers", headers);
        return await host.Client.SendAsync(request);
    }

    private static string? AllowOrigin(HttpResponseMessage response) =>
        response.Headers.TryGetValues("Access-Control-Allow-Origin", out var values) ? values.Single() : null;

    [Fact]
    public async Task Un_origen_configurado_recibe_la_cabecera_en_una_peticion_normal()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, configuration: Origins(Web));

        var response = await Get(host, "/api/businesses", Web);

        Assert.Equal(Web, AllowOrigin(response));
    }

    [Theory]
    [InlineData("/api/businesses")]
    [InlineData("/api/auth/login")]
    [InlineData("/api/admin/businesses")]
    [InlineData("/api/sync/push")]
    public async Task La_peticion_previa_se_responde_sin_autenticar_con_metodos_y_cabeceras_de_la_api(string path)
    {
        await using var host = await ApiTestHost.StartAsync(postgres, configuration: Origins(Web));

        var response = await Preflight(host, path, Web);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Equal(Web, AllowOrigin(response));
        var methods = string.Join(",", response.Headers.GetValues("Access-Control-Allow-Methods"));
        foreach (var method in new[] { "GET", "POST", "PATCH", "DELETE" })
        {
            Assert.Contains(method, methods);
        }
        var allowed = string.Join(",", response.Headers.GetValues("Access-Control-Allow-Headers")).ToLowerInvariant();
        foreach (var header in new[] { "authorization", "content-type", "x-business-id" })
        {
            Assert.Contains(header, allowed);
        }
        Assert.False(response.Headers.Contains("Access-Control-Allow-Credentials"));
    }

    [Fact]
    public async Task Un_origen_no_configurado_no_recibe_cabeceras_ni_en_la_peticion_ni_en_la_previa()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, configuration: Origins(Web));

        var simple = await Get(host, "/api/businesses", "https://sitio-malicioso.example");
        var preflight = await Preflight(host, "/api/businesses", "https://sitio-malicioso.example");

        Assert.Null(AllowOrigin(simple));
        Assert.Null(AllowOrigin(preflight));
    }

    [Fact]
    public async Task Sin_configuracion_no_se_permite_ningun_origen()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var simple = await Get(host, "/api/businesses", Web);
        var preflight = await Preflight(host, "/api/businesses", Web);

        Assert.Null(AllowOrigin(simple));
        Assert.Null(AllowOrigin(preflight));
    }

    [Fact]
    public async Task Varios_origenes_con_espacios_y_barra_final_se_toleran()
    {
        await using var host = await ApiTestHost.StartAsync(
            postgres, configuration: Origins($" {Web}/ , https://pulperia.tudominio.com ,, "));

        var first = await Get(host, "/api/businesses", Web);
        Assert.Equal(Web, AllowOrigin(first));
        // Con varios orígenes la respuesta depende del origen: las cachés deben saberlo.
        Assert.Contains("Origin", first.Headers.Vary);
        Assert.Equal(
            "https://pulperia.tudominio.com",
            AllowOrigin(await Get(host, "/api/businesses", "https://pulperia.tudominio.com")));
    }

    [Fact]
    public async Task Un_asterisco_no_abre_la_api_a_cualquier_origen()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, configuration: Origins("*"));

        Assert.Null(AllowOrigin(await Get(host, "/api/businesses", Web)));
        Assert.Null(AllowOrigin(await Preflight(host, "/api/businesses", Web)));
    }

    [Fact]
    public async Task CORS_no_reemplaza_la_autenticacion_de_las_rutas()
    {
        await using var host = await ApiTestHost.StartAsync(postgres, configuration: Origins(Web));

        var response = await Get(host, "/api/admin/businesses", Web);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(Web, AllowOrigin(response));
    }
}
