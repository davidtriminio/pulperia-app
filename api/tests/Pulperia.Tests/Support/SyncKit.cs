using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Access;
using Pulperia.Infrastructure.Persistence.Entities;

namespace Pulperia.Tests.Support;

/// <summary>Una cuenta de prueba ya iniciada: su token de acceso, su usuario y el negocio que creó al registrarse.</summary>
public sealed record SyncAccount(string Token, Guid UserId, Guid BusinessId);

/// <summary>
/// La API real con un negocio de Ana (dueña) y ayudas para hablar con la sincronización por HTTP,
/// como lo hará el móvil: enviar lotes de operaciones y pedir cambios por cursor (Fase 7).
/// </summary>
public sealed class SyncKit : IAsyncDisposable
{
    private SyncKit(ApiTestHost host, SyncAccount owner)
    {
        Host = host;
        Owner = owner;
    }

    public ApiTestHost Host { get; }

    /// <summary>Ana, dueña del negocio de la prueba.</summary>
    public SyncAccount Owner { get; }

    public Guid BusinessId => Owner.BusinessId;

    public static async Task<SyncKit> StartAsync(PostgresFixture postgres, TimeProvider? clock = null)
    {
        var host = await ApiTestHost.StartAsync(postgres, clock: clock);
        return new SyncKit(host, await RegisterAsync(host, "ana@correo.com"));
    }

    /// <summary>Registra una cuenta con un negocio propio e inicia sesión.</summary>
    public static async Task<SyncAccount> RegisterAsync(ApiTestHost host, string email)
    {
        var register = await ApiTestHost.JsonOf(await host.PostAsync("/api/auth/register", new
        {
            email, password = "contrasena1", businessName = $"Negocio de {email}",
            amountMode = "two_decimals", quantityMode = "fractional",
        }));
        var login = await ApiTestHost.JsonOf(
            await host.PostAsync("/api/auth/login", new { email, password = "contrasena1" }));
        return new SyncAccount(
            login.GetProperty("accessToken").GetString()!,
            register.GetProperty("userId").GetGuid(),
            register.GetProperty("businessId").GetGuid());
    }

    /// <summary>Una cuenta nueva que además es empleada del negocio de Ana.</summary>
    public async Task<SyncAccount> AddEmployeeAsync(string email)
    {
        var account = await RegisterAsync(Host, email);
        Host.Db.Memberships.Add(new MembershipEntity { UserId = account.UserId, BusinessId = BusinessId, Role = Role.Employee });
        await Host.Db.SaveChangesAsync();
        return account;
    }

    /// <summary>Quita a la persona del negocio de Ana como lo hace el dueño (queda removida, con su último lote disponible).</summary>
    public async Task RemoveAsync(SyncAccount account)
    {
        var membership = await Host.Db.Memberships.SingleAsync(m => m.UserId == account.UserId && m.BusinessId == BusinessId);
        membership.Status = Pulperia.Domain.Team.MembershipStatus.Removed;
        membership.RemovedAt = OperationKit.At.UtcDateTime;
        await Host.Db.SaveChangesAsync();
    }

    /// <summary>Una operación tal como la envía el móvil (camelCase, con su <c>opId</c>).</summary>
    public static object SyncOp(string type, Guid entityId, object? payload = null, int? baseVersion = null, Guid? opId = null) => new
    {
        opId = opId ?? Guid.CreateVersion7(),
        type,
        entityId,
        payload = payload ?? new { },
        baseVersion,
        createdAt = OperationKit.At,
    };

    public Task<HttpResponseMessage> PushAsync(SyncAccount from, params object[] operations) =>
        Host.PostAsync("/api/sync/push", new { operations }, from.Token, BusinessId);

    /// <summary>Envía un lote que debe aceptarse (HTTP 200) y devuelve la lista <c>results</c>.</summary>
    public async Task<JsonElement[]> PushOkAsync(SyncAccount from, params object[] operations)
    {
        var response = await PushAsync(from, operations);
        var body = await ApiTestHost.JsonOf(response);
        Assert.True(response.IsSuccessStatusCode, $"{(int)response.StatusCode}: {body}");
        return body.GetProperty("results").EnumerateArray().ToArray();
    }

    public Task<HttpResponseMessage> PullAsync(SyncAccount from, long cursor = 0, int? limit = null) =>
        Host.GetAsync($"/api/sync/pull?cursor={cursor}" + (limit is { } l ? $"&limit={l}" : ""), from.Token, BusinessId);

    public async Task<JsonElement> PullOkAsync(SyncAccount from, long cursor = 0, int? limit = null)
    {
        var response = await PullAsync(from, cursor, limit);
        var body = await ApiTestHost.JsonOf(response);
        Assert.True(response.IsSuccessStatusCode, $"{(int)response.StatusCode}: {body}");
        return body;
    }

    public static string Status(JsonElement result) => result.GetProperty("status").GetString()!;

    public static string? Code(JsonElement result) =>
        result.TryGetProperty("code", out var code) ? code.GetString() : null;

    public ValueTask DisposeAsync() => Host.DisposeAsync();
}
