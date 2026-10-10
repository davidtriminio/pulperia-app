using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.EntityFrameworkCore;
using Pulperia.Api;
using Pulperia.Infrastructure.Persistence;

namespace Pulperia.Tests.Support;

/// <summary>
/// La API real en Kestrel sobre un puerto libre y una base de datos propia, para probar HTTP
/// de verdad sin paquetes de pruebas extra. Usa pocas iteraciones de hash para ir rápido.
/// </summary>
public sealed class ApiTestHost : IAsyncDisposable
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private ApiTestHost(WebApplication app, HttpClient client, PulperiaDbContext db)
    {
        App = app;
        Client = client;
        Db = db;
    }

    public WebApplication App { get; }

    public HttpClient Client { get; }

    /// <summary>Un contexto aparte sobre la misma base, para comprobar lo que quedó guardado.</summary>
    public PulperiaDbContext Db { get; }

    /// <param name="mapExtra">Rutas de prueba que se agregan antes de arrancar.</param>
    /// <param name="activateNewBusinesses">
    /// El negocio que crea un registro nace pendiente de activación (D-30). Para que las demás
    /// pruebas trabajen con él, por omisión se activa al instante, como lo haría el super
    /// administrador; las pruebas de activación lo desactivan.
    /// </param>
    public static async Task<ApiTestHost> StartAsync(
        PostgresFixture postgres, Action<WebApplication>? mapExtra = null, TimeProvider? clock = null,
        bool activateNewBusinesses = true)
    {
        var admin = await postgres.CreateDatabaseAsync();
        var connectionString = admin.Database.GetConnectionString()!;
        await admin.DisposeAsync();

        var app = ApiHost.Build(
            [],
            builder =>
            {
                builder.Configuration["ConnectionStrings:Pulperia"] = connectionString;
                builder.Configuration["Auth:PasswordIterations"] = "1000";
                builder.WebHost.UseUrls("http://127.0.0.1:0");
                if (clock is not null)
                {
                    builder.Services.AddSingleton(clock);
                }
            });
        mapExtra?.Invoke(app);
        await app.StartAsync();

        var address = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.First();
        var client = activateNewBusinesses
            ? new HttpClient(new ActivatingHandler(connectionString)) { BaseAddress = new Uri(address) }
            : new HttpClient { BaseAddress = new Uri(address) };
        return new ApiTestHost(app, client, PostgresFixture.NewContext(connectionString));
    }

    /// <summary>Activa el negocio que acaba de crear un registro, para pruebas que no tratan de la activación.</summary>
    private sealed class ActivatingHandler(string connectionString) : DelegatingHandler(new HttpClientHandler())
    {
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var body = request.Content is null ? "" : await request.Content.ReadAsStringAsync(cancellationToken);
            var response = await base.SendAsync(request, cancellationToken);
            if (request.Method == HttpMethod.Post
                && request.RequestUri?.AbsolutePath == "/api/auth/register"
                && response.StatusCode == System.Net.HttpStatusCode.Created
                && !body.Contains("invitationCode", StringComparison.Ordinal))
            {
                using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
                var id = json.RootElement.GetProperty("businessId").GetGuid();
                await using var db = PostgresFixture.NewContext(connectionString);
                await db.Businesses.Where(b => b.Id == id)
                    .ExecuteUpdateAsync(s => s.SetProperty(b => b.Status, Pulperia.Domain.Business.BusinessStatus.Active), cancellationToken);
            }
            return response;
        }
    }

    public async Task<HttpResponseMessage> PostAsync(string path, object? body, string? accessToken = null, Guid? businessId = null)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = JsonContent.Create(body, options: Json) };
        Decorate(request, accessToken, businessId);
        return await Client.SendAsync(request);
    }

    public async Task<HttpResponseMessage> GetAsync(string path, string? accessToken = null, Guid? businessId = null)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        Decorate(request, accessToken, businessId);
        return await Client.SendAsync(request);
    }

    public async Task<HttpResponseMessage> PatchAsync(string path, object? body, string? accessToken = null, Guid? businessId = null)
    {
        using var request = new HttpRequestMessage(HttpMethod.Patch, path) { Content = JsonContent.Create(body, options: Json) };
        Decorate(request, accessToken, businessId);
        return await Client.SendAsync(request);
    }

    public async Task<HttpResponseMessage> DeleteAsync(string path, string? accessToken = null, Guid? businessId = null)
    {
        using var request = new HttpRequestMessage(HttpMethod.Delete, path);
        Decorate(request, accessToken, businessId);
        return await Client.SendAsync(request);
    }

    /// <summary>Envía el JSON tal cual, para probar cuerpos que un objeto C# no puede expresar.</summary>
    public async Task<HttpResponseMessage> SendJsonAsync(
        HttpMethod method, string path, string? json, string? accessToken = null, Guid? businessId = null)
    {
        using var request = new HttpRequestMessage(method, path);
        if (json is not null)
        {
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
        }
        Decorate(request, accessToken, businessId);
        return await Client.SendAsync(request);
    }

    public static async Task<JsonElement> JsonOf(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement.Clone();

    private static void Decorate(HttpRequestMessage request, string? accessToken, Guid? businessId)
    {
        if (accessToken is not null)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        }
        if (businessId is not null)
        {
            request.Headers.Add("X-Business-Id", businessId.Value.ToString());
        }
    }

    public async ValueTask DisposeAsync()
    {
        Client.Dispose();
        await Db.DisposeAsync();
        await App.StopAsync();
        await App.DisposeAsync();
    }
}
