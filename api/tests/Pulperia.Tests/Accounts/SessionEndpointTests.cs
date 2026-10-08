using System.Net;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Accounts;

/// <summary>T064: <c>/api/auth/login</c>, <c>/refresh</c> y <c>/logout</c> sobre la API real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SessionEndpointTests(PostgresFixture postgres)
{
    private static async Task<ApiTestHost> StartWithAccount(PostgresFixture postgres)
    {
        var host = await ApiTestHost.StartAsync(postgres);
        var register = await host.PostAsync("/api/auth/register", new
        {
            email = "ana@correo.com", password = "contrasena1", businessName = "Pulpería Ana",
            amountMode = "two_decimals", quantityMode = "fractional",
        });
        Assert.Equal(HttpStatusCode.Created, register.StatusCode);
        return host;
    }

    private static Task<HttpResponseMessage> Login(ApiTestHost host, string password = "contrasena1") =>
        host.PostAsync("/api/auth/login", new { email = "ana@correo.com", password });

    [Fact]
    public async Task Iniciar_sesion_responde_200_con_los_tokens_y_sus_caducidades()
    {
        await using var host = await StartWithAccount(postgres);

        var response = await Login(host);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await ApiTestHost.JsonOf(response);
        Assert.Matches("^[A-Za-z0-9_-]{43}$", json.GetProperty("accessToken").GetString()!);
        Assert.Matches("^[A-Za-z0-9_-]{43}$", json.GetProperty("refreshToken").GetString()!);
        Assert.True(json.GetProperty("accessExpiresAt").GetDateTimeOffset() < json.GetProperty("refreshExpiresAt").GetDateTimeOffset());
        Assert.NotEqual(Guid.Empty, json.GetProperty("userId").GetGuid());
    }

    [Fact]
    public async Task Credenciales_erroneas_responden_401_invalid_credentials()
    {
        await using var host = await StartWithAccount(postgres);

        var response = await Login(host, "otra-contrasena");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("invalid_credentials", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Renovar_responde_200_con_tokens_nuevos_y_el_anterior_responde_401()
    {
        await using var host = await StartWithAccount(postgres);
        var login = await ApiTestHost.JsonOf(await Login(host));
        var refresh = login.GetProperty("refreshToken").GetString();

        var renewed = await host.PostAsync("/api/auth/refresh", new { refreshToken = refresh });
        var again = await host.PostAsync("/api/auth/refresh", new { refreshToken = refresh });

        Assert.Equal(HttpStatusCode.OK, renewed.StatusCode);
        Assert.NotEqual(refresh, (await ApiTestHost.JsonOf(renewed)).GetProperty("refreshToken").GetString());
        Assert.Equal(HttpStatusCode.Unauthorized, again.StatusCode);
        Assert.Equal("invalid_refresh_token", (await ApiTestHost.JsonOf(again)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Cerrar_sesion_responde_204_y_despues_la_renovacion_deja_de_servir()
    {
        await using var host = await StartWithAccount(postgres);
        var login = await ApiTestHost.JsonOf(await Login(host));

        var logout = await host.PostAsync(
            "/api/auth/logout", null, login.GetProperty("accessToken").GetString());
        var refresh = await host.PostAsync(
            "/api/auth/refresh", new { refreshToken = login.GetProperty("refreshToken").GetString() });

        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
    }

    [Fact]
    public async Task Cerrar_sesion_sin_token_responde_401_unauthorized()
    {
        await using var host = await StartWithAccount(postgres);

        var response = await host.PostAsync("/api/auth/logout", null);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("unauthorized", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Cuerpos_sin_la_forma_esperada_responden_400_invalid_request()
    {
        await using var host = await StartWithAccount(postgres);

        var login = await host.PostAsync("/api/auth/login", new { email = "ana@correo.com" });
        var refresh = await host.PostAsync("/api/auth/refresh", new { });

        Assert.Equal(HttpStatusCode.BadRequest, login.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, refresh.StatusCode);
    }
}
