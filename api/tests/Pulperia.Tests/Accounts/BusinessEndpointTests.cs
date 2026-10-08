using System.Net;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Accounts;

/// <summary>T065: <c>GET</c> y <c>POST /api/businesses</c> sobre la API real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class BusinessEndpointTests(PostgresFixture postgres)
{
    private static async Task<string> RegisterAndLogin(ApiTestHost host)
    {
        await host.PostAsync("/api/auth/register", new
        {
            email = "ana@correo.com", password = "contrasena1", businessName = "Pulpería Ana",
            amountMode = "two_decimals", quantityMode = "fractional",
        });
        var login = await ApiTestHost.JsonOf(
            await host.PostAsync("/api/auth/login", new { email = "ana@correo.com", password = "contrasena1" }));
        return login.GetProperty("accessToken").GetString()!;
    }

    [Fact]
    public async Task Listar_negocios_responde_con_id_nombre_rol_y_modos()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var token = await RegisterAndLogin(host);

        var response = await host.GetAsync("/api/businesses", token);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var item = Assert.Single((await ApiTestHost.JsonOf(response)).EnumerateArray());
        Assert.Equal("Pulpería Ana", item.GetProperty("name").GetString());
        Assert.Equal("owner", item.GetProperty("role").GetString());
        Assert.Equal("two_decimals", item.GetProperty("amountMode").GetString());
        Assert.Equal("fractional", item.GetProperty("quantityMode").GetString());
        Assert.NotEqual(Guid.Empty, item.GetProperty("id").GetGuid());
    }

    [Fact]
    public async Task Crear_un_negocio_responde_201_y_aparece_en_el_listado()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var token = await RegisterAndLogin(host);

        var created = await host.PostAsync(
            "/api/businesses", new { name = "Segunda sucursal", amountMode = "integer", quantityMode = "integer" }, token);
        var list = await ApiTestHost.JsonOf(await host.GetAsync("/api/businesses", token));

        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var json = await ApiTestHost.JsonOf(created);
        Assert.Equal("Segunda sucursal", json.GetProperty("name").GetString());
        Assert.Equal("owner", json.GetProperty("role").GetString());
        Assert.Equal(2, list.GetArrayLength());
    }

    [Fact]
    public async Task Crear_un_negocio_sin_nombre_responde_400_con_su_codigo()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var token = await RegisterAndLogin(host);

        var response = await host.PostAsync(
            "/api/businesses", new { name = "", amountMode = "integer", quantityMode = "integer" }, token);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("business_name_required", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Theory]
    [InlineData("hexagonal", "integer", "amount_mode_invalid")]
    [InlineData("integer", "mucho", "quantity_mode_invalid")]
    public async Task Un_modo_desconocido_responde_400(string amount, string quantity, string code)
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var token = await RegisterAndLogin(host);

        var response = await host.PostAsync("/api/businesses", new { name = "X", amountMode = amount, quantityMode = quantity }, token);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(code, (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Sin_token_con_token_desconocido_o_caducado_responde_401()
    {
        var clock = new FixedClock(AccountKit.Start);
        await using var host = await ApiTestHost.StartAsync(postgres, clock: clock);
        var token = await RegisterAndLogin(host);

        var none = await host.GetAsync("/api/businesses");
        var unknown = await host.GetAsync("/api/businesses", "desconocido");
        var postNone = await host.PostAsync("/api/businesses", new { name = "X", amountMode = "integer", quantityMode = "integer" });
        clock.Advance(TimeSpan.FromMinutes(16));
        var expired = await host.GetAsync("/api/businesses", token);

        foreach (var response in new[] { none, unknown, postNone, expired })
        {
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Equal("unauthorized", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
        }
    }

    [Fact]
    public async Task Tras_cerrar_sesion_el_token_ya_no_sirve_para_listar()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var token = await RegisterAndLogin(host);

        await host.PostAsync("/api/auth/logout", null, token);

        Assert.Equal(HttpStatusCode.Unauthorized, (await host.GetAsync("/api/businesses", token)).StatusCode);
    }
}
