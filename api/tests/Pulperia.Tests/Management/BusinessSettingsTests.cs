using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Management;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Management;

/// <summary>T067: leer y cambiar ajustes y nombre del negocio, solo el dueño (RF-7, RF-8, RF-9, RF-80).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class BusinessSettingsTests(PostgresFixture postgres)
{
    // ---- servicio

    [Fact]
    public async Task El_dueno_lee_el_nombre_y_los_modos_del_negocio()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync(Registration(amountMode: AmountMode.Integer, quantityMode: QuantityMode.Fractional));

        var result = await kit.Management.GetSettingsAsync(account.BusinessId, Role.Owner);

        Assert.True(result.IsSuccess);
        Assert.Equal(("Pulpería Ana", AmountMode.Integer, QuantityMode.Fractional),
            (result.Value!.Name, result.Value.AmountMode, result.Value.QuantityMode));
    }

    [Fact]
    public async Task El_dueno_cambia_el_nombre_y_se_aplica_a_todos_los_usuarios()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var result = await kit.Management.UpdateSettingsAsync(
            account.BusinessId, Role.Owner, new SettingsChange(Name: "  Pulpería Doña Ana  "));

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        Assert.Equal("Pulpería Doña Ana", (await kit.Db.Businesses.AsNoTracking().SingleAsync()).Name);
        Assert.Equal("Pulpería Doña Ana", Assert.Single(await kit.Service.ListBusinessesAsync(account.UserId)).Name);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Un_nombre_vacio_se_rechaza_y_no_cambia_nada(string name)
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var result = await kit.Management.UpdateSettingsAsync(account.BusinessId, Role.Owner, new SettingsChange(Name: name));

        Assert.Equal(["business_name_required"], result.Codes);
        Assert.Equal("Pulpería Ana", (await kit.Db.Businesses.AsNoTracking().SingleAsync()).Name);
    }

    [Fact]
    public async Task Pasar_de_enteros_a_decimales_se_aplica_sin_tocar_los_registros()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync(Registration(amountMode: AmountMode.Integer, quantityMode: QuantityMode.Integer));

        var result = await kit.Management.UpdateSettingsAsync(
            account.BusinessId, Role.Owner,
            new SettingsChange(AmountMode: AmountMode.TwoDecimals, QuantityMode: QuantityMode.Fractional));

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        var business = await kit.Db.Businesses.AsNoTracking().SingleAsync();
        Assert.Equal((AmountMode.TwoDecimals, QuantityMode.Fractional), (business.AmountMode, business.QuantityMode));
    }

    [Fact]
    public async Task Pasar_de_decimales_a_enteros_se_rechaza()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var amounts = await kit.Management.UpdateSettingsAsync(
            account.BusinessId, Role.Owner, new SettingsChange(AmountMode: AmountMode.Integer));
        var quantities = await kit.Management.UpdateSettingsAsync(
            account.BusinessId, Role.Owner, new SettingsChange(QuantityMode: QuantityMode.Integer));

        Assert.Equal(["mode_downgrade_not_allowed"], amounts.Codes);
        Assert.Equal(["mode_downgrade_not_allowed"], quantities.Codes);
        var business = await kit.Db.Businesses.AsNoTracking().SingleAsync();
        Assert.Equal((AmountMode.TwoDecimals, QuantityMode.Fractional), (business.AmountMode, business.QuantityMode));
    }

    [Fact]
    public async Task Un_cambio_rechazado_no_aplica_ni_siquiera_los_otros_campos()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var result = await kit.Management.UpdateSettingsAsync(
            account.BusinessId, Role.Owner, new SettingsChange(Name: "Nuevo", AmountMode: AmountMode.Integer));

        Assert.False(result.IsSuccess);
        Assert.Equal("Pulpería Ana", (await kit.Db.Businesses.AsNoTracking().SingleAsync()).Name);
    }

    [Fact]
    public async Task Repetir_el_mismo_modo_es_valido()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var result = await kit.Management.UpdateSettingsAsync(
            account.BusinessId, Role.Owner,
            new SettingsChange(AmountMode: AmountMode.TwoDecimals, QuantityMode: QuantityMode.Fractional));

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task Un_empleado_no_puede_leer_ni_cambiar_nada()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var read = await kit.Management.GetSettingsAsync(account.BusinessId, Role.Employee);
        var write = await kit.Management.UpdateSettingsAsync(
            account.BusinessId, Role.Employee, new SettingsChange(Name: "Hackeado", AmountMode: AmountMode.TwoDecimals));

        Assert.Equal(["forbidden"], read.Codes);
        Assert.Equal(["forbidden"], write.Codes);
        Assert.Equal("Pulpería Ana", (await kit.Db.Businesses.AsNoTracking().SingleAsync()).Name);
    }

    // ---- HTTP

    private static async Task<(string Token, Guid BusinessId)> Register(ApiTestHost host, string email = "ana@correo.com")
    {
        var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
        {
            email, password = "contrasena1", businessName = "Pulpería Ana", amountMode = "two_decimals", quantityMode = "fractional",
        }));
        var login = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
        return (login.GetProperty("accessToken").GetString()!, register.GetProperty("businessId").GetGuid());
    }

    [Fact]
    public async Task GET_negocio_responde_los_ajustes_al_dueno()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var (token, businessId) = await Register(host);

        var response = await host.GetAsync("/api/business", token, businessId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await ApiTestHost.JsonOf(response);
        Assert.Equal(("Pulpería Ana", "two_decimals", "fractional"),
            (json.GetProperty("name").GetString(), json.GetProperty("amountMode").GetString(), json.GetProperty("quantityMode").GetString()));
    }

    [Fact]
    public async Task PATCH_negocio_cambia_solo_los_campos_enviados()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var (token, businessId) = await Register(host);

        var response = await host.PatchAsync("/api/business", new { name = "Nuevo nombre" }, token, businessId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var business = await host.Db.Businesses.AsNoTracking().SingleAsync();
        Assert.Equal(("Nuevo nombre", AmountMode.TwoDecimals), (business.Name, business.AmountMode));
        Assert.Equal("Nuevo nombre", (await ApiTestHost.JsonOf(response)).GetProperty("name").GetString());
    }

    [Fact]
    public async Task PATCH_con_un_downgrade_responde_400_con_su_codigo()
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var (token, businessId) = await Register(host);

        var response = await host.PatchAsync("/api/business", new { amountMode = "integer" }, token, businessId);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("mode_downgrade_not_allowed", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    [Theory]
    [InlineData("""{"amountMode":"hexagonal"}""", "amount_mode_invalid")]
    [InlineData("""{"quantityMode":"mucho"}""", "quantity_mode_invalid")]
    [InlineData("""{"name":5}""", "invalid_request")]
    public async Task PATCH_con_valores_desconocidos_responde_400(string json, string code)
    {
        await using var host = await ApiTestHost.StartAsync(postgres);
        var (token, businessId) = await Register(host);

        var response = await host.SendJsonAsync(HttpMethod.Patch, "/api/business", json, token, businessId);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(code, (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }
}
