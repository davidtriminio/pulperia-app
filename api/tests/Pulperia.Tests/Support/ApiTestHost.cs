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
    public static async Task<ApiTestHost> StartAsync(
        PostgresFixture postgres, Action<WebApplication>? mapExtra = null, TimeProvider? clock = null)
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
        var client = new HttpClient { BaseAddress = new Uri(address) };
        return new ApiTestHost(app, client, PostgresFixture.NewContext(connectionString));
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
