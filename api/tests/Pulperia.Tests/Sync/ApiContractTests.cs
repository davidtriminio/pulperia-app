using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.Routing.Patterns;
using Microsoft.Extensions.DependencyInjection;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Sync;

/// <summary>
/// T086: el contrato <c>shared/openapi.json</c> describe lo que la API hace de verdad (D-17). Las
/// rutas del servidor y las del contrato son las mismas, y una pasada por cada operación comprueba
/// que cada petición y cada respuesta real cumplen su esquema, y que no queda en el contrato ninguna
/// respuesta que nadie haya visto.
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class ApiContractTests(PostgresFixture postgres)
{
    private static readonly OpenApiContract Contract = OpenApiContract.Load();
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    /// <summary>Las rutas del servidor como (MÉTODO, ruta) con los parámetros sin restricciones: <c>{id:guid}</c> es <c>{id}</c>.</summary>
    private static IEnumerable<(string Method, string Path)> ServerRoutes(ApiTestHost host) =>
        host.App.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(e => e.RoutePattern.RawText is { } raw && raw.StartsWith("/api/"))
            .SelectMany(e => e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods
                .Select(m => (m, Regex.Replace(e.RoutePattern.RawText!.TrimEnd('/'), @"\{(\w+):[^}]+\}", "{$1}"))));

    [Fact]
    public async Task Las_rutas_del_servidor_y_las_del_contrato_son_las_mismas()
    {
        await using var kit = await StartAsync(postgres);

        var server = ServerRoutes(kit.Host).Order().ToArray();
        var contract = Contract.Operations().Order().ToArray();

        Assert.Equal(contract, server);
    }

    /// <summary>Recuerda qué respuestas se vieron y las valida contra el contrato.</summary>
    private sealed class Probe(ApiTestHost host)
    {
        public HashSet<(string Method, string Path, int Status)> Seen { get; } = [];

        public async Task<JsonElement?> Call(
            string method, string template, string actualPath, int expected,
            object? body = null, string? token = null, Guid? business = null, string? rawJson = null)
        {
            // Una petición válida debe cumplir el esquema de petición del contrato.
            if (body is not null && Contract.RequestSchema(method, template) is { } requestSchema)
            {
                var problems = Contract.Validate(JsonSerializer.SerializeToElement(body, Web), requestSchema);
                Assert.True(problems.Count == 0, $"{method} {template}: la petición no cumple el contrato:\n{string.Join("\n", problems)}");
            }

            using var response = rawJson is not null
                ? await host.SendJsonAsync(new HttpMethod(method), actualPath, rawJson, token, business)
                : method switch
                {
                    "GET" => await host.GetAsync(actualPath, token, business),
                    "POST" => await host.PostAsync(actualPath, body, token, business),
                    "PATCH" => await host.PatchAsync(actualPath, body, token, business),
                    "DELETE" => await host.DeleteAsync(actualPath, token, business),
                    _ => throw new InvalidOperationException(method),
                };
            var text = await response.Content.ReadAsStringAsync();

            Assert.True((int)response.StatusCode == expected, $"{method} {actualPath}: se esperaba {expected} y fue {(int)response.StatusCode}: {text}");
            Assert.True(Contract.IsDocumented(method, template, expected), $"{method} {template}: el contrato no documenta la respuesta {expected}");

            JsonElement? json = null;
            if (Contract.ResponseSchema(method, template, expected) is { } schema)
            {
                json = JsonDocument.Parse(text).RootElement.Clone();
                var problems = Contract.Validate(json.Value, schema);
                Assert.True(problems.Count == 0, $"{method} {template} {expected}: la respuesta no cumple el contrato:\n{string.Join("\n", problems)}\n{text}");
            }
            else
            {
                Assert.True(text.Length == 0, $"{method} {template} {expected}: el contrato no documenta cuerpo y llegó: {text}");
            }

            Seen.Add((method, template, expected));
            return json;
        }
    }

    [Fact]
    public async Task Cada_peticion_y_respuesta_real_cumple_el_contrato_y_no_sobra_ninguna_respuesta_documentada()
    {
        await using var kit = await StartAsync(postgres);
        var probe = new Probe(kit.Host);
        var ana = kit.Owner;
        var biz = kit.BusinessId;

        var beto = await kit.AddEmployeeAsync("beto@correo.com");
        var dora = await kit.AddEmployeeAsync("dora@correo.com");
        var carla = await RegisterAsync(kit.Host, "carla@correo.com");
        var erika = await RegisterAsync(kit.Host, "erika@correo.com");
        var frank = await RegisterAsync(kit.Host, "frank@correo.com");
        var greta = await RegisterAsync(kit.Host, "greta@correo.com");
        var outsider = await RegisterAsync(kit.Host, "otra@correo.com");
        string Random() => Guid.CreateVersion7().ToString();

        // ---- Cuentas y sesiones ----
        await probe.Call("POST", "/api/auth/register", "/api/auth/register", 201,
            new { email = "nueva@correo.com", password = "contrasena1", businessName = "Nueva", amountMode = "integer", quantityMode = "integer" });
        await probe.Call("POST", "/api/auth/register", "/api/auth/register", 409,
            new { email = "nueva@correo.com", password = "contrasena1", businessName = "Nueva", amountMode = "integer", quantityMode = "integer" });
        await probe.Call("POST", "/api/auth/register", "/api/auth/register", 400, rawJson: "{}");

        var login = (await probe.Call("POST", "/api/auth/login", "/api/auth/login", 200,
            new { email = "ana@correo.com", password = "contrasena1" }))!.Value;
        await probe.Call("POST", "/api/auth/login", "/api/auth/login", 401, new { email = "ana@correo.com", password = "equivocada" });
        await probe.Call("POST", "/api/auth/login", "/api/auth/login", 400, rawJson: "{}");

        var refreshed = (await probe.Call("POST", "/api/auth/refresh", "/api/auth/refresh", 200,
            new { refreshToken = login.GetProperty("refreshToken").GetString() }))!.Value;
        await probe.Call("POST", "/api/auth/refresh", "/api/auth/refresh", 401, new { refreshToken = "no-sirve" });
        await probe.Call("POST", "/api/auth/refresh", "/api/auth/refresh", 400, rawJson: "{}");
        await probe.Call("POST", "/api/auth/logout", "/api/auth/logout", 204, token: refreshed.GetProperty("accessToken").GetString());

        // ---- Negocios del usuario ----
        await probe.Call("GET", "/api/businesses", "/api/businesses", 200, token: ana.Token);
        await probe.Call("POST", "/api/businesses", "/api/businesses", 201,
            new { name = "Segunda sucursal", amountMode = "two_decimals", quantityMode = "fractional" }, ana.Token);
        await probe.Call("POST", "/api/businesses", "/api/businesses", 400,
            new { name = "", amountMode = "two_decimals", quantityMode = "fractional" }, ana.Token);

        // ---- Ajustes ----
        await probe.Call("GET", "/api/business", "/api/business", 200, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/business", "/api/business", 403, token: beto.Token, business: biz);
        await probe.Call("PATCH", "/api/business", "/api/business", 200, new { name = "Pulpería Ana 2" }, ana.Token, biz);
        await probe.Call("PATCH", "/api/business", "/api/business", 400, rawJson: "{\"amountMode\":\"otro\"}", token: ana.Token, business: biz);
        await probe.Call("PATCH", "/api/business", "/api/business", 403, new { name = "Intento" }, beto.Token, biz);

        // ---- Invitaciones del dueño ----
        var byEmail = (await probe.Call("POST", "/api/business/invitations", "/api/business/invitations", 201,
            new { email = "carla@correo.com" }, ana.Token, biz))!.Value;
        var byCode = (await probe.Call("POST", "/api/business/invitations", "/api/business/invitations", 201,
            new { }, ana.Token, biz))!.Value;
        var forErika = (await probe.Call("POST", "/api/business/invitations", "/api/business/invitations", 201,
            new { email = "erika@correo.com" }, ana.Token, biz))!.Value;
        await probe.Call("POST", "/api/business/invitations", "/api/business/invitations", 400, new { email = "sin-arroba" }, ana.Token, biz);
        await probe.Call("POST", "/api/business/invitations", "/api/business/invitations", 403, new { email = "x@correo.com" }, beto.Token, biz);
        await probe.Call("POST", "/api/business/invitations", "/api/business/invitations", 409, new { email = "beto@correo.com" }, ana.Token, biz);
        await probe.Call("GET", "/api/business/invitations", "/api/business/invitations", 200, token: ana.Token, business: biz);
        var toCancel = (await probe.Call("POST", "/api/business/invitations", "/api/business/invitations", 201,
            new { email = "cancelar@correo.com" }, ana.Token, biz))!.Value.GetProperty("id").GetString();
        await probe.Call("DELETE", "/api/business/invitations/{id}", $"/api/business/invitations/{toCancel}", 204, token: ana.Token, business: biz);
        await probe.Call("DELETE", "/api/business/invitations/{id}", $"/api/business/invitations/{toCancel}", 409, token: ana.Token, business: biz);
        await probe.Call("DELETE", "/api/business/invitations/{id}", $"/api/business/invitations/{Random()}", 404, token: ana.Token, business: biz);

        // ---- Invitaciones del invitado ----
        await probe.Call("GET", "/api/invitations", "/api/invitations", 200, token: carla.Token);
        var carlaOffer = byEmail.GetProperty("id").GetString();
        await probe.Call("POST", "/api/invitations/{id}/accept", $"/api/invitations/{carlaOffer}/accept", 200, token: carla.Token);
        await probe.Call("POST", "/api/invitations/{id}/accept", $"/api/invitations/{carlaOffer}/accept", 409, token: carla.Token);
        await probe.Call("POST", "/api/invitations/{id}/accept", $"/api/invitations/{forErika.GetProperty("id").GetString()}/accept", 403, token: carla.Token);
        await probe.Call("POST", "/api/invitations/{id}/accept", $"/api/invitations/{Random()}/accept", 404, token: carla.Token);
        await probe.Call("POST", "/api/invitations/{id}/reject", $"/api/invitations/{forErika.GetProperty("id").GetString()}/reject", 403, token: carla.Token);
        await probe.Call("POST", "/api/invitations/{id}/reject", $"/api/invitations/{Random()}/reject", 404, token: erika.Token);
        await probe.Call("POST", "/api/invitations/{id}/reject", $"/api/invitations/{forErika.GetProperty("id").GetString()}/reject", 204, token: erika.Token);

        var code = byCode.GetProperty("code").GetString();
        await probe.Call("POST", "/api/invitations/redeem", "/api/invitations/redeem", 200, new { code }, frank.Token);
        await probe.Call("POST", "/api/invitations/redeem", "/api/invitations/redeem", 404, new { code = "ZZZZZZZZ" }, frank.Token);
        for (var i = 0; i < 9; i++)
        {
            await probe.Call("POST", "/api/invitations/redeem", "/api/invitations/redeem", 404, new { code = "ZZZZZZZZ" }, greta.Token);
        }
        await probe.Call("POST", "/api/invitations/redeem", "/api/invitations/redeem", 404, new { code = "ZZZZZZZZ" }, greta.Token);
        await probe.Call("POST", "/api/invitations/redeem", "/api/invitations/redeem", 429, new { code = "ZZZZZZZZ" }, greta.Token);

        // ---- Equipo ----
        await probe.Call("GET", "/api/business/team", "/api/business/team", 200, token: ana.Token, business: biz);
        await probe.Call("POST", "/api/business/team/{userId}/promote", $"/api/business/team/{dora.UserId}/promote", 200, token: ana.Token, business: biz);
        await probe.Call("POST", "/api/business/team/{userId}/promote", $"/api/business/team/{Random()}/promote", 404, token: ana.Token, business: biz);
        await probe.Call("DELETE", "/api/business/team/{userId}", $"/api/business/team/{Random()}", 404, token: ana.Token, business: biz);
        await probe.Call("DELETE", "/api/business/team/{userId}", $"/api/business/team/{dora.UserId}", 204, token: ana.Token, business: biz);
        await probe.Call("DELETE", "/api/business/team/{userId}", $"/api/business/team/{ana.UserId}", 409, token: ana.Token, business: biz);

        // ---- Sincronización y operaciones ----
        Guid client = Guid.CreateVersion7(), product = Guid.CreateVersion7(), fiado = Guid.CreateVersion7();
        var batch = new
        {
            operations = new[]
            {
                SyncOp("client.create", client, ClientPayload("Ana López", phone: "98765432")),
                SyncOp("product.create", product, new { name = "Arroz", price = 2500, unit = "pound" }),
                SyncOp("fiado.create", fiado, FiadoPayload(client, 1250, Item(quantity: 500, unitPrice: 2500, subtotal: 1250, productId: product))),
                SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(client, 400)),
                SyncOp("product.update", product, new { name = "Arroz", price = 2800, unit = "pound" }, baseVersion: 1),
            },
        };
        var pushed = (await probe.Call("POST", "/api/sync/push", "/api/sync/push", 200, batch, ana.Token, biz))!.Value;
        Assert.All(pushed.GetProperty("results").EnumerateArray(), r => Assert.Equal("applied", r.GetProperty("status").GetString()));

        // Una operación repetida y una rechazada: así el contrato ve también duplicate y rejected con sus códigos.
        var again = await probe.Call("POST", "/api/sync/push", "/api/sync/push", 200,
            new { operations = new[] { batch.operations[0], SyncOp("payment.create", Guid.CreateVersion7(), PaymentPayload(Guid.CreateVersion7(), 5)) } },
            ana.Token, biz);
        Assert.Equal(["duplicate", "rejected"], again!.Value.GetProperty("results").EnumerateArray().Select(Status).ToArray());
        await probe.Call("POST", "/api/sync/push", "/api/sync/push", 400, rawJson: "{}", token: ana.Token, business: biz);
        await probe.Call("POST", "/api/sync/push", "/api/sync/push", 403, new { operations = Array.Empty<object>() }, outsider.Token, biz);

        var page = (await probe.Call("GET", "/api/sync/pull", "/api/sync/pull", 200, token: ana.Token, business: biz))!.Value;
        Assert.Equal(["client", "fiado", "payment", "product"], page.GetProperty("changes").EnumerateArray().Select(c => c.GetProperty("type").GetString()).ToArray());
        var small = (await probe.Call("GET", "/api/sync/pull", "/api/sync/pull?cursor=1&limit=1", 200, token: ana.Token, business: biz))!.Value;
        Assert.True(small.GetProperty("hasMore").GetBoolean());
        await probe.Call("GET", "/api/sync/pull", "/api/sync/pull?cursor=abc", 400, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/sync/pull", "/api/sync/pull", 403, token: outsider.Token, business: biz);

        var single = (await probe.Call("POST", "/api/operations", "/api/operations", 200,
            new { opId = Guid.CreateVersion7(), type = "client.create", entityId = Guid.CreateVersion7(), payload = ClientPayload("Beto Web") }, ana.Token, biz))!.Value;
        Assert.Equal("applied", Status(single));
        var rejected = (await probe.Call("POST", "/api/operations", "/api/operations", 200,
            new { opId = Guid.CreateVersion7(), type = "payment.create", entityId = Guid.CreateVersion7(), payload = PaymentPayload(Guid.CreateVersion7(), 5), createdAt = OperationKit.At }, ana.Token, biz))!.Value;
        Assert.Equal("rejected", Status(rejected));
        await probe.Call("POST", "/api/operations", "/api/operations", 400, rawJson: "{}", token: ana.Token, business: biz);
        await probe.Call("POST", "/api/operations", "/api/operations", 403,
            new { opId = Guid.CreateVersion7(), type = "client.create", entityId = Guid.CreateVersion7(), payload = ClientPayload("X") }, outsider.Token, biz);

        // ---- Consultas ----
        await probe.Call("GET", "/api/clients", "/api/clients", 200, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/clients", "/api/clients?archived=true", 200, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/clients", "/api/clients?archived=quizas", 400, token: ana.Token, business: biz);
        var detail = (await probe.Call("GET", "/api/clients/{id}", $"/api/clients/{client}", 200, token: ana.Token, business: biz))!.Value;
        Assert.Equal(["fiado", "payment"], detail.GetProperty("movements").EnumerateArray().Select(m => m.GetProperty("kind").GetString()).ToArray());
        await probe.Call("GET", "/api/clients/{id}", $"/api/clients/{Random()}", 404, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/products", "/api/products", 200, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/products", "/api/products?archived=1", 400, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/summary", "/api/summary", 200, token: ana.Token, business: biz);
        await probe.Call("GET", "/api/summary", "/api/summary?limit=0", 400, token: ana.Token, business: biz);

        // ---- Sin sesión: el 401 de todas las rutas que lo documentan y aún no se vieron ----
        foreach (var (method, template, status) in Contract.Responses().Where(r => r.Status == 401).ToArray())
        {
            if (!probe.Seen.Contains((method, template, status)))
            {
                var path = Regex.Replace(template, @"\{\w+\}", _ => Random());
                await probe.Call(method, template, path, 401, business: biz);
            }
        }

        // ---- Nada del contrato queda sin comprobar ----
        var unchecked_ = Contract.Responses().Where(r => !probe.Seen.Contains(r)).ToArray();
        Assert.True(unchecked_.Length == 0, "Respuestas documentadas que ninguna prueba vio: " + string.Join(", ", unchecked_));
    }
}
