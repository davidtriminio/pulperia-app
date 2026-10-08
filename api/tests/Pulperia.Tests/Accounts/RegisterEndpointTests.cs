using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Accounts;

/// <summary>T063: <c>POST /api/auth/register</c> sobre la API real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class RegisterEndpointTests(PostgresFixture postgres)
{
    private static object Body(
        string email = "ana@correo.com", string password = "contrasena1", string? businessName = "Pulpería Ana",
        string amountMode = "two_decimals", string quantityMode = "fractional") =>
        new { email, password, businessName, amountMode, quantityMode };

    [Fact]
    public async Task Registrarse_responde_201_con_los_ids_y_deja_la_cuenta_guardada()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var response = await host.PostAsync("/api/auth/register", Body());

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var json = await ApiTestHost.JsonOf(response);
        var business = await host.Db.Businesses.AsNoTracking().SingleAsync();
        Assert.Equal(business.Id, json.GetProperty("businessId").GetGuid());
        Assert.Equal((await host.Db.Users.AsNoTracking().SingleAsync()).Id, json.GetProperty("userId").GetGuid());
        Assert.Equal("Pulpería Ana", business.Name);
    }

    [Fact]
    public async Task Sin_nombre_de_negocio_responde_400_con_su_codigo()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var response = await host.PostAsync("/api/auth/register", Body(businessName: ""));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var json = await ApiTestHost.JsonOf(response);
        Assert.Equal("business_name_required", json.GetProperty("code").GetString());
        Assert.Empty(host.Db.Users);
    }

    [Fact]
    public async Task Un_correo_ya_registrado_responde_409()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        await host.PostAsync("/api/auth/register", Body());

        var response = await host.PostAsync("/api/auth/register", Body("ANA@correo.com", businessName: "Otra"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("email_taken", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Theory]
    [InlineData("hexagonal", "fractional", "amount_mode_invalid")]
    [InlineData("two_decimals", "mucho", "quantity_mode_invalid")]
    public async Task Un_modo_desconocido_responde_400(string amountMode, string quantityMode, string code)
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var response = await host.PostAsync("/api/auth/register", Body(amountMode: amountMode, quantityMode: quantityMode));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(code, (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Fact]
    public async Task Un_cuerpo_ausente_o_que_no_es_un_objeto_responde_400_invalid_request()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);

        var empty = await host.PostAsync("/api/auth/register", null);
        var text = await host.PostAsync("/api/auth/register", "hola");
        var missing = await host.PostAsync("/api/auth/register", new { email = "ana@correo.com" });

        Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(empty)).GetProperty("code").GetString());
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(text)).GetProperty("code").GetString());
        Assert.Equal("invalid_request", (await ApiTestHost.JsonOf(missing)).GetProperty("code").GetString());
    }
}
