using System.Net;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Business;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Admin;

/// <summary>
/// T189: listado, búsqueda y ficha de negocios y cuentas con cifras agregadas, sin ningún dato de
/// fiados (RF-97, RF-82, D-29).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class AdminDirectoryTests(PostgresFixture postgres)
{
    private sealed record World(SyncKit Kit, SyncAccount Admin, SyncAccount Ana, SyncAccount Beto, SyncAccount Carla);

    /// <summary>Ana (dueña del negocio de la prueba), Beto y Carla con su negocio, y un super administrador.</summary>
    private async Task<World> Setup()
    {
        var kit = await StartAsync(postgres);
        var beto = await RegisterAsync(kit.Host, "beto@correo.com");
        var carla = await RegisterAsync(kit.Host, "carla@correo.com");
        var admin = await RegisterAsync(kit.Host, "root@plataforma.com");
        await kit.Host.Db.Users.Where(u => u.Id == admin.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));
        return new World(kit, admin, kit.Owner, beto, carla);
    }

    private static async Task<JsonElement> GetOk(World w, string path)
    {
        var response = await w.Kit.Host.GetAsync(path, w.Admin.Token);
        var body = await ApiTestHost.JsonOf(response);
        Assert.True(response.IsSuccessStatusCode, $"{(int)response.StatusCode}: {body}");
        return body;
    }

    private static string[] Names(JsonElement page) =>
        page.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("name").GetString()!).ToArray();

    private static string[] Emails(JsonElement page) =>
        page.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("email").GetString()!).ToArray();

    // ---- negocios

    [Fact]
    public async Task Lista_los_negocios_ordenados_por_nombre_con_su_pagina_y_el_total()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var page = await GetOk(w, "/api/admin/businesses");

        Assert.Equal(
            ["Negocio de ana@correo.com", "Negocio de beto@correo.com", "Negocio de carla@correo.com", "Negocio de root@plataforma.com"],
            Names(page));
        Assert.Equal((1, 25, 4), (page.GetProperty("page").GetInt32(), page.GetProperty("pageSize").GetInt32(), page.GetProperty("total").GetInt32()));
    }

    [Fact]
    public async Task Pagina_con_el_tamano_pedido_y_acota_los_valores_absurdos()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var second = await GetOk(w, "/api/admin/businesses?page=2&pageSize=3");
        var clamped = await GetOk(w, "/api/admin/businesses?page=-4&pageSize=100000");

        Assert.Equal(["Negocio de root@plataforma.com"], Names(second));
        Assert.Equal((2, 3, 4), (second.GetProperty("page").GetInt32(), second.GetProperty("pageSize").GetInt32(), second.GetProperty("total").GetInt32()));
        Assert.Equal((1, 100), (clamped.GetProperty("page").GetInt32(), clamped.GetProperty("pageSize").GetInt32()));
    }

    [Fact]
    public async Task Busca_negocios_por_nombre_o_por_correo_de_un_dueno_sin_distinguir_mayusculas()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var byName = await GetOk(w, "/api/admin/businesses?search=CARLA");
        var byOwner = await GetOk(w, "/api/admin/businesses?search=beto@");

        Assert.Equal(["Negocio de carla@correo.com"], Names(byName));
        Assert.Equal(["Negocio de beto@correo.com"], Names(byOwner));
    }

    [Fact]
    public async Task Filtra_los_negocios_por_estado()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.Host.Db.Businesses.Where(b => b.Id == w.Beto.BusinessId).ExecuteUpdateAsync(s => s
            .SetProperty(b => b.Status, BusinessStatus.Pending));
        await w.Kit.Host.Db.Businesses.Where(b => b.Id == w.Carla.BusinessId).ExecuteUpdateAsync(s => s
            .SetProperty(b => b.Status, BusinessStatus.Suspended).SetProperty(b => b.StatusReason, "Falta de pago"));

        var pending = await GetOk(w, "/api/admin/businesses?status=pending");
        var suspended = await GetOk(w, "/api/admin/businesses?status=suspended");
        var all = await GetOk(w, "/api/admin/businesses");

        Assert.Equal(["Negocio de beto@correo.com"], Names(pending));
        Assert.Equal(["Negocio de carla@correo.com"], Names(suspended));
        Assert.Equal(4, all.GetProperty("total").GetInt32());
        var carla = suspended.GetProperty("items")[0];
        Assert.Equal(("suspended", "Falta de pago"), (carla.GetProperty("status").GetString(), carla.GetProperty("statusReason").GetString()));
    }

    [Fact]
    public async Task Un_estado_desconocido_responde_400()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await w.Kit.Host.GetAsync("/api/admin/businesses?status=archivado", w.Admin.Token);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task La_ficha_trae_duenos_miembros_ultima_sincronizacion_y_conteos_correctos()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var employee = await w.Kit.AddEmployeeAsync("dora@correo.com");
        Guid c1 = Guid.CreateVersion7(), c2 = Guid.CreateVersion7(), product = Guid.CreateVersion7();
        await w.Kit.PushOkAsync(
            w.Ana,
            SyncOp("client.create", c1, ClientPayload("Cliente Uno")),
            SyncOp("client.create", c2, ClientPayload("Cliente Dos")),
            SyncOp("product.create", product, new { name = "Arroz", price = 2500 }),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(c1, 5000)),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(c2, 1200)),
            SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(c1, 700)));
        var lastSync = await w.Kit.Host.Db.ProcessedOps.IgnoreQueryFilters().AsNoTracking()
            .Where(p => p.BusinessId == w.Ana.BusinessId).MaxAsync(p => p.ProcessedAt);

        var ficha = await GetOk(w, $"/api/admin/businesses/{w.Ana.BusinessId}");

        Assert.Equal(w.Ana.BusinessId, ficha.GetProperty("id").GetGuid());
        Assert.Equal(["ana@correo.com"], ficha.GetProperty("ownerEmails").EnumerateArray().Select(e => e.GetString()));
        Assert.Equal(2, ficha.GetProperty("memberCount").GetInt32());
        Assert.Equal("active", ficha.GetProperty("status").GetString());
        Assert.Equal((2, 1, 2, 1),
            (ficha.GetProperty("clientCount").GetInt32(), ficha.GetProperty("productCount").GetInt32(),
             ficha.GetProperty("fiadoCount").GetInt32(), ficha.GetProperty("paymentCount").GetInt32()));
        Assert.Equal(lastSync, ficha.GetProperty("lastSyncAt").GetDateTime().ToUniversalTime());
        Assert.NotEqual(Guid.Empty, employee.UserId);
    }

    [Fact]
    public async Task Un_negocio_que_nunca_sincronizo_no_tiene_ultima_sincronizacion_y_cuenta_cero()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var ficha = await GetOk(w, $"/api/admin/businesses/{w.Beto.BusinessId}");

        Assert.Equal(JsonValueKind.Null, ficha.GetProperty("lastSyncAt").ValueKind);
        Assert.Equal((0, 0, 0, 0),
            (ficha.GetProperty("clientCount").GetInt32(), ficha.GetProperty("productCount").GetInt32(),
             ficha.GetProperty("fiadoCount").GetInt32(), ficha.GetProperty("paymentCount").GetInt32()));
    }

    [Fact]
    public async Task Un_negocio_inexistente_responde_404()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await w.Kit.Host.GetAsync($"/api/admin/businesses/{Guid.CreateVersion7()}", w.Admin.Token);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("business_not_found", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    // ---- cuentas

    [Fact]
    public async Task Lista_y_busca_cuentas_por_correo_con_sus_negocios()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.AddEmployeeAsync("dora@correo.com");

        var all = await GetOk(w, "/api/admin/accounts");
        var search = await GetOk(w, "/api/admin/accounts?search=DORA");

        Assert.Equal(
            ["ana@correo.com", "beto@correo.com", "carla@correo.com", "dora@correo.com", "root@plataforma.com"], Emails(all));
        Assert.Equal(["dora@correo.com"], Emails(search));
        var dora = search.GetProperty("items")[0];
        Assert.Equal(
            [("Negocio de ana@correo.com", "employee", "active"), ("Negocio de dora@correo.com", "owner", "active")],
            dora.GetProperty("businesses").EnumerateArray()
                .Select(b => (b.GetProperty("name").GetString()!, b.GetProperty("role").GetString()!, b.GetProperty("status").GetString()!))
                .OrderBy(b => b.Item1, StringComparer.Ordinal));
    }

    [Fact]
    public async Task La_ficha_de_una_cuenta_muestra_su_estado_y_si_es_super_administrador()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await w.Kit.Host.Db.Users.Where(u => u.Id == w.Beto.UserId).ExecuteUpdateAsync(s => s
            .SetProperty(u => u.SuspendedAt, DateTime.UtcNow).SetProperty(u => u.SuspensionReason, "Abuso"));

        var beto = await GetOk(w, $"/api/admin/accounts/{w.Beto.UserId}");
        var admin = await GetOk(w, $"/api/admin/accounts/{w.Admin.UserId}");

        Assert.Equal(("Abuso", false), (beto.GetProperty("suspensionReason").GetString(), beto.GetProperty("isSuperAdmin").GetBoolean()));
        Assert.NotEqual(JsonValueKind.Null, beto.GetProperty("suspendedAt").ValueKind);
        Assert.True(admin.GetProperty("isSuperAdmin").GetBoolean());
        Assert.Equal(JsonValueKind.Null, admin.GetProperty("suspendedAt").ValueKind);
    }

    [Fact]
    public async Task Una_cuenta_inexistente_responde_404()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await w.Kit.Host.GetAsync($"/api/admin/accounts/{Guid.CreateVersion7()}", w.Admin.Token);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("account_not_found", (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString());
    }

    // ---- privacidad (RF-82, RF-97)

    private static readonly string[] AllowedBusinessFields =
    [
        "id", "name", "ownerEmails", "memberCount", "createdAt", "status", "statusReason", "lastSyncAt",
        "clientCount", "productCount", "fiadoCount", "paymentCount",
    ];

    private static readonly string[] AllowedAccountFields =
        ["id", "email", "createdAt", "isSuperAdmin", "suspendedAt", "suspensionReason", "businesses"];

    private static readonly string[] AllowedAccountBusinessFields = ["id", "name", "role", "status"];

    [Fact]
    public async Task Ninguna_respuesta_trae_nombres_de_clientes_ni_de_productos_montos_ni_deudas()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        Guid client = Guid.CreateVersion7();
        await w.Kit.PushOkAsync(
            w.Ana,
            SyncOp("client.create", client, ClientPayload("Cliente Secreto Zuñiga")),
            SyncOp("product.create", Guid.CreateVersion7(), new { name = "Producto Reservado XYZ", price = 987654 }),
            SyncOp("fiado.create", Guid.CreateVersion7(), FiadoPayload(client, 123456)));

        var responses = new List<JsonElement>
        {
            await GetOk(w, "/api/admin/businesses"),
            await GetOk(w, $"/api/admin/businesses/{w.Ana.BusinessId}"),
            await GetOk(w, "/api/admin/accounts"),
            await GetOk(w, $"/api/admin/accounts/{w.Ana.UserId}"),
        };

        foreach (var response in responses)
        {
            var text = response.GetRawText();
            foreach (var secret in new[] { "Zuñiga", "Cliente Secreto", "Producto Reservado", "987654", "123456", "balance", "debt" })
            {
                Assert.DoesNotContain(secret, text);
            }
        }

        // Y los campos son exactamente los permitidos: un campo nuevo exige decidirlo aquí.
        var businesses = responses[0].GetProperty("items").EnumerateArray().Append(responses[1]);
        foreach (var business in businesses)
        {
            Assert.Equal(AllowedBusinessFields.Order(), business.EnumerateObject().Select(p => p.Name).Order());
        }
        var accounts = responses[2].GetProperty("items").EnumerateArray().Append(responses[3]);
        foreach (var account in accounts)
        {
            Assert.Equal(AllowedAccountFields.Order(), account.EnumerateObject().Select(p => p.Name).Order());
            foreach (var business in account.GetProperty("businesses").EnumerateArray())
            {
                Assert.Equal(AllowedAccountBusinessFields.Order(), business.EnumerateObject().Select(p => p.Name).Order());
            }
        }
    }

    [Fact]
    public async Task Un_usuario_normal_no_ve_ningun_listado()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        foreach (var path in new[]
                 {
                     "/api/admin/businesses", $"/api/admin/businesses/{w.Ana.BusinessId}",
                     "/api/admin/accounts", $"/api/admin/accounts/{w.Ana.UserId}",
                 })
        {
            var response = await w.Kit.Host.GetAsync(path, w.Beto.Token, w.Beto.BusinessId);

            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        }
    }
}
